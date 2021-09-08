variable "region" {
  default = "eu-west-1"
}

variable "environment" {
  default = "PRODUCTION"
}

variable "vpc_id" {
  default = "vpc-0123456789"
}

# Private subnets where the worker nodes will we deployed
variable "private_subnets" {
  default = ["subnet-0123456789a", "subnet-0123456789b", "subnet-0123456789c"]
}

# Allow access to Kubernetes API from an IP or CIDR
variable "allowed_cidr_to_access_k8s_api" {
  default = ["172.16.12.0/22"]
}

# Security groups pre-created for the workers nodes
variable "security_groups_for_nodes" {
  default = ["sg-0123456789a", "sg-0123456789b"]
}

# Read this post about this section
# https://varlogdiego.com/eks-your-current-user-or-role-does-not-have-access-to-kubernetes
variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      userarn  = "arn:aws:iam::0123456789:user/diego"
      username = "diego"
      groups   = ["system:masters"]
    }
  ]
}

# Read this post about this section
# https://varlogdiego.com/eks-your-current-user-or-role-does-not-have-access-to-kubernetes
variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      rolearn  = "arn:aws:iam::0123456789:role/devops"
      username = "devops"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::0123456789:role/developers"
      username = "developers"
      groups   = ["eks-console"]
    }
  ]
}
