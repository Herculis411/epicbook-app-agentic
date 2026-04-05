########################################################################
# Secrets — AWS Secrets Manager
# Generates db_password and jwt_secret at apply time using
# random_password. Stores them in Secrets Manager so they never
# appear in terraform.tfvars, user_data, or plan output.
#
# EC2 app instances fetch these at runtime via:
#   aws secretsmanager get-secret-value --secret-id <arn>
########################################################################

resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#%&*_+=?"   # shell-safe: no $, ", ', \, `
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false                   # alphanumeric — safe in all contexts
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-${var.environment}-db-password"
  description             = "RDS master password for ${var.project_name} ${var.environment}"
  recovery_window_in_days = 0       # allow immediate re-deploy without name collision
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}-${var.environment}-jwt-secret"
  description             = "JWT signing secret for ${var.project_name} ${var.environment} backend"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}
