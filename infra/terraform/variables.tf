variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro for free tier)"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 in eu-north-1"
  type        = string
  default     = "ami-0705384c0b33c194c"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "devops-stage6-key"
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "ubuntu"
}

variable "github_username" {
  description = "GitHub username for cloning repository"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "jfive.mooo.com"
}

variable "email" {
  description = "Email for notifications and SSL certificates"
  type        = string
  default     = "josiahfavour02@gmail.com"
}
