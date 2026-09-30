module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.26.0"

  name               = var.eks_cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  control_plane_subnet_ids = module.vpc.private_subnets

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_irsa = true

  enable_cluster_creator_admin_permissions = true

  authentication_mode = "API_AND_CONFIG_MAP"

  security_group_additional_rules = {
    ingress_nodes_443 = {
      description              = "Node groups to EKS cluster API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_node_security_group = true
    }
  }

  addons = {
    vpc-cni = {
      most_recent  = true
      before_compute = true
    }

    kube-proxy = {
      most_recent  = true
      before_compute = true
    }

    coredns = {
      most_recent = true
    }

    eks-pod-identity-agent = {
      most_recent  = true
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    nutriflow_nodes = {
      name = "nutriflow-node-group"

      ami_type = "AL2023_x86_64_STANDARD"

      instance_types = [
        var.node_instance_type
      ]

      capacity_type = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      disk_size = 20

      subnet_ids = module.vpc.private_subnets

      labels = {
        Project = "NutriFlow"
      }

      tags = {
        Project     = "NutriFlow"
        Environment = var.environment
        ManagedBy   = "Terraform"
      }
    }
  }

  tags = {
    Project     = "NutriFlow"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
