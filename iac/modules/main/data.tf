locals {
  core_output_prefix = "/${var.namespace}/${var.env}/core"
}

# Network
locals {
  private_subnets = split(",", data.aws_ssm_parameter.private_subnets.value)
}

data "aws_ssm_parameter" "vpc_id" {
  name = "${local.core_output_prefix}/vpc_id"
}

data "aws_ssm_parameter" "private_subnets" {
  name = "${local.core_output_prefix}/private_subnets"
}

# CI/CD
data "aws_ssm_parameter" "codestar_connection_arn" {
  name = "${local.core_output_prefix}/codestar_connection_arn"
}
