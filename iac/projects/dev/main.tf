# ------------------------------------------------------------------------------
# email-ai-agent
# Inbound email AI chat agent
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.14"

  backend "s3" {
    profile = "terraform-dev"
    region  = "us-east-1"
    bucket  = "924586450630-terraform-state"
    key     = "email-ai-agent/dev/terraform.tfstate.json"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "terraform-dev"
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------

module "main" {
  source = "../../modules/main"

  namespace = "ik"
  env       = "dev"
  is_prod   = false

  source_repository_url = var.source_repository_url
  git_branch            = "memory" # TODO revert to "main"

  inbound_domain        = var.inbound_domain
  inbound_email_address = var.inbound_email_address
  route53_zone_name     = var.route53_zone_name

  allowed_email_addresses_dynamo_table_name = var.allowed_email_addresses_dynamo_table_name
}
