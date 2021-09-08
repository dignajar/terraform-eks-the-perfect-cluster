# Terraform for EKS: The perfect cluster

## Features
- EKS with node groups
- Private EKS cluster, the control plane and workers nodes are only accessible from the same VPC
- CPU nodes `m5d.xlarge` and `m5d.2xlarge`
- GPU nodes `g4dn.xlarge` and `g4dn.2xlarge`
- Root partition `32GB` and storage class `gp3`
- Docker partition from the NVMe SSD instance store volumes
- Tags for [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- IAM role for [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- Setup for [aws-auth config-map](https://varlogdiego.com/eks-your-current-user-or-role-does-not-have-access-to-kubernetes)
- Enabled IAM Roles for Service Accounts (IRSA)
- Amazon VPC CNI replaced for Calico CNI

## Cluster Autoscaler
The Terraform prepare the following component for the CA.
- Tagging the Autoscaling groups with the GPU taint tag. `k8s.io/cluster-autoscaler/node-template/taint/dedicated = gpu:NoSchedule`
- Creates the IAM role `cluster-autoscaler-role` with proper policies.
