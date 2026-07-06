#-------------------------------------------------------------------------------
# Main local varialble setup
#-------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  aws_region = data.aws_region.current.region

  id            = "${var.namespace}-${var.env}-email-ai-agent"
  output_prefix = "/${var.namespace}/${var.env}/email-ai-agent"

  tags = merge(var.tags, {
    Terraform   = true
    Environment = var.env
    is_prod     = var.is_prod
  })
}
