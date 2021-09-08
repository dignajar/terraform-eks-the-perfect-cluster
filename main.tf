provider "aws" {
  region = var.region
}

locals {
  cluster_name    = "eks-perfect"
  cluster_version = "1.21"
}

module "eks-perfect" {
  # Terraform module
  source  = "terraform-aws-modules/eks/aws"
  version = "17.15.0"

  # Cluster name and version
  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  # Prevent kubeconfig file creation
  write_kubeconfig = false

  # VPC
  vpc_id  = var.vpc_id
  subnets = var.private_subnets

  # Set as private cluster, only accesible from the same VPC
  cluster_endpoint_public_access                 = false
  cluster_endpoint_private_access                = true
  cluster_create_endpoint_private_access_sg_rule = true
  cluster_endpoint_private_access_cidrs          = var.allowed_cidr_to_access_k8s_api

  # aws-auth config-map
  map_users = var.map_users
  map_roles = var.map_roles

  # Enable IAM Roles for Service Accounts
  enable_irsa = true

  # Cluster tags
  tags = {
    name        = local.cluster_name
    Environment = var.environment
  }

  # Node groups

  ## Security groups for node groups
  worker_additional_security_group_ids = var.security_groups_for_nodes

  ## General values for all node groups
  node_groups_defaults = {
    create_launch_template = true
    disk_size              = 32 # 32GB for the root partition
    disk_type              = "gp3"
    pre_userdata           = "mkfs.xfs -f -n ftype=1 /dev/nvme1n1; mkdir -p /var/lib/docker; mount /dev/nvme1n1 /var/lib/docker"
    desired_capacity       = 0 # Keep the desired capacity in zero until the AWS CNI plugin is deleted
    min_capacity           = 0
    max_capacity           = 10
    update_config = {
      max_unavailable_percentage = 25
    }
  }

  ## Specific values for each node group
  node_groups = {
    cpu-xlarge = {
      instance_types = ["m5d.xlarge"]
      ami_type       = "AL2_x86_64"
    },
    cpu-2xlarge = {
      instance_types = ["m5d.2xlarge"]
      ami_type       = "AL2_x86_64"
    },
    gpu-xlarge = {
      instance_types     = ["g4dn.xlarge"]
      ami_type           = "AL2_x86_64_GPU"
      kubelet_extra_args = "--register-with-taints=dedicated=gpu:NoSchedule --node-labels=dedicated=gpu"
    },
    gpu-2xlarge = {
      instance_types     = ["g4dn.2xlarge"]
      ami_type           = "AL2_x86_64_GPU"
      kubelet_extra_args = "--register-with-taints=dedicated=gpu:NoSchedule --node-labels=dedicated=gpu"
    }
  }
}

// ----------------------------------------------------------------------------
// Kubernetes provider for manipulate config-map aws-auth, required for the Terraform module
// ----------------------------------------------------------------------------
data "aws_eks_cluster" "cluster" {
  name = module.eks-perfect.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks-perfect.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

// ----------------------------------------------------------------------------
// Delete AWS CNI and apply Calico CNI
// ----------------------------------------------------------------------------
resource "null_resource" "delete-aws-cni" {
  depends_on = [module.eks-perfect]

  provisioner "local-exec" {
    command = "kubectl --server=${data.aws_eks_cluster.cluster.endpoint} --token=${data.aws_eks_cluster_auth.cluster.token} --insecure-skip-tls-verify=true delete daemonset -n kube-system aws-node; exit 0"
  }
}

resource "null_resource" "deploy-calico-cni" {
  depends_on = [null_resource.delete-aws-cni]

  provisioner "local-exec" {
    command = "kubectl --server=${data.aws_eks_cluster.cluster.endpoint} --token=${data.aws_eks_cluster_auth.cluster.token} --insecure-skip-tls-verify=true apply -f https://docs.projectcalico.org/manifests/calico-vxlan.yaml; exit 0"
  }
}

// ----------------------------------------------------------------------------
// Cluster Autoscaler: Autoscaling group extra tags for the GPU taint
// ----------------------------------------------------------------------------
resource "aws_autoscaling_group_tag" "asg-ca-gpu-taint" {
  depends_on = [module.eks-perfect]

  for_each = {
    for key, nodegroup in module.eks-perfect.node_groups : key => nodegroup
    if nodegroup.ami_type == "AL2_x86_64_GPU"
  }

  autoscaling_group_name = each.value.resources[0].autoscaling_groups[0].name
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/taint/dedicated"
    value               = "gpu:NoSchedule"
    propagate_at_launch = false
  }
}

// ----------------------------------------------------------------------------
// Cluster Autoscaler: IAM Roles for Service Accounts
// ----------------------------------------------------------------------------
data "aws_iam_policy_document" "cluster" {
  depends_on = [module.eks-perfect]

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks-perfect.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks-perfect.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }
  }
}

resource "aws_iam_role" "cluster-autoscaler-role" {
  name               = "cluster-autoscaler-role"
  assume_role_policy = data.aws_iam_policy_document.cluster.json
}
