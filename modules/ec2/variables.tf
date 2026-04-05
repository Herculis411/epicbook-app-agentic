########################################################################
# EC2 Module — Variables
# Fix: removed semicolons (invalid HCL syntax)
########################################################################

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "web_subnet_ids" {
  type = list(string)
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "web_sg_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "web_target_group_arn" {
  type = string
}

variable "app_target_group_arn" {
  type = string
}

variable "key_name" {
  type = string
}

variable "web_instance_type" {
  type = string
}

variable "app_instance_type" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "aws_region" {
  type        = string
  description = "AWS region — passed to bootstrap script for Secrets Manager calls"
}

variable "db_password_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret containing the RDS password"
}

variable "public_alb_dns" {
  type = string
}

variable "internal_alb_dns" {
  type = string
}

variable "jwt_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret containing the JWT signing secret"
}

variable "allowed_origins" {
  type = string
}
