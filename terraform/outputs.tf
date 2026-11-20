output "vpc_id" {
  description = "NutriFlow VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "NutriFlow private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "NutriFlow public subnet IDs"
  value       = module.vpc.public_subnets
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS Kubernetes version"
  value       = module.eks.cluster_version
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "jenkins_iam_role_name" {
  description = "IAM Role Name for Jenkins EC2 Instance"
  value       = aws_iam_role.jenkins_role.name
}

output "jenkins_iam_instance_profile_name" {
  description = "IAM Instance Profile Name to attach to EC2"
  value       = aws_iam_instance_profile.jenkins_instance_profile.name
}
