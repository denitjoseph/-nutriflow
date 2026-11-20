# ==============================================================================
# IAM Role and Instance Profile for Jenkins EC2 Instance
# ==============================================================================

# 1. Trust Relationship (Allows EC2 instance to assume this role)
resource "aws_iam_role" "jenkins_role" {
  name = "${var.project_name}-jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = "NutriFlow"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 2. Attach ECR Power User (Push & Pull Docker Images)
resource "aws_iam_role_policy_attachment" "jenkins_ecr_power_user" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# 3. Attach AdministratorAccess (Allows running Terraform to create VPC, EKS, NodeGroups, IAM roles without permission denial)
resource "aws_iam_role_policy_attachment" "jenkins_admin_access" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 3. Custom Policy: Access EKS cluster & update kubeconfig
resource "aws_iam_policy" "jenkins_eks_policy" {
  name        = "${var.project_name}-jenkins-eks-policy"
  description = "Allows Jenkins to interact with EKS and describe cluster resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_eks_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = aws_iam_policy.jenkins_eks_policy.arn
}

# 4. Instance Profile (Attached directly to EC2 instance)
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "${var.project_name}-jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name

  tags = {
    Project     = "NutriFlow"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
