variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "peex-project"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "prometheus_instance_type" {
  description = "EC2 instance type for Prometheus (Free Tier eligible: t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "grafana_instance_type" {
  description = "EC2 instance type for Grafana (Free Tier eligible: t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "EC2 instance type for sample application (Free Tier eligible: t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
  default     = []
}

variable "enable_ssh_access" {
  description = "Enable SSH access (should be false in production, use Session Manager instead)"
  type        = bool
  default     = false
}
