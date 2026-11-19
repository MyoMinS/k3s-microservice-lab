variable "aws_region" {
  description = "AWS region for the EC2 instance and ECR repositories."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Unique prefix for AWS resources and ECR repositories (lowercase letters, digits and hyphens)."
  type        = string
  default     = "k3s-microservice-lab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,35}$", var.project_name))
    error_message = "Use 3-36 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "key_pair_name" {
  description = "Name of an existing AWS EC2 SSH key pair in aws_region."
  type        = string
}

variable "admin_cidr" {
  description = "Your public IP/32; SSH and Kubernetes API are restricted to this range."
  type        = string
  #validation {
  #  condition     = can(cidrhost(var.admin_cidr, 0))
  #  error_message = "Provide a valid IPv4 CIDR, preferably your own IP/32."
  #}
}

variable "http_cidrs" {
  description = "Allowed source ranges for the HTTP demo gateway."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "Size sufficient for single-node k3s and the Helm add-ons."
  type        = string
  default     = "t3.medium"
}

variable "github_repository" {
  description = "Public GitHub repository owner/name to trust for OIDC pushes from main (empty disables the CI role)."
  type        = string
  default     = ""
  validation {
    condition     = var.github_repository == "" || can(regex("^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$", var.github_repository))
    error_message = "Enter owner/repo or leave empty."
  }
}