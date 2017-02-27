variable "resource_tag" {
  description = "Name Tag to precede all resources"
  default = "project-dev"
}

variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-west-2"
}

variable "cidr_block" {
  description = "The cidr block of the VPC you would like to create"
  default     = "10.10.0.0/16"
}

variable "enable_dns_hostnames" { default = true }
variable "enable_dns_support" { default = true }

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "profile" {
  description = "Target AWS account for this deployment via .aws/credentials"
  default = ""
}

variable "instance_type" {
  default     = "t2.small"
  description = "AWS EC2 instance type behind this ECS cluster"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "2"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "5"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "2"
}

variable "bucket_name" {
  description = "S3 Bucket to store remote state"
  default = "ecs-alb-efs-terraform-state"
}

variable "internal_elb" {
  description = "Make ALB private? (Compute nodes are always private under ALB)"
  default = false
}
