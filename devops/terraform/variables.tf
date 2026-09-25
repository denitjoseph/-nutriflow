variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "nutriflow"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "nutriflow-cluster"
}

variable "node_instance_type" {
  description = "EKS worker node instance type"
  type        = string
  default     = "t3.micro"
}

variable "node_count" {
  description = "Number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = "vpc-05ec0be5ebf60d910"
}

variable "subnet_ids" {
  description = "Existing subnet IDs for EKS"
  type        = list(string)

  default = [
    "subnet-04689b391a6a20fa3",
    "subnet-02c157fb7d51664e7",
    "subnet-0865acac612817608"
  ]
}