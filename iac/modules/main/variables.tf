variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "namespace" {
  description = "Project namespace to use as a base for most resources"
}

variable "env" {
  description = "Environment used for tagging images etc."
}

variable "is_prod" {
  description = ""
  type        = bool
}

# CodeBuild

variable "source_repository_url" {
  description = "HTTPS clone URL of the GitHub repository"
  type        = string
}

variable "git_branch" {
  description = "Git branch to build"
  type        = string
  default     = "main"
}

# SES

variable "inbound_domain" {
  description = "Subdomain whose MX record points at SES inbound (e.g. aimail.example.com)"
  type        = string
}

variable "inbound_email_address" {
  description = "Address the agent receives mail at; must be on inbound_domain"
  type        = string
}

variable "route53_zone_name" {
  description = "Existing public Route53 hosted zone that contains inbound_domain"
  type        = string
}

variable "allowed_email_addresses_dynamo_table_name" {
  description = "DynamoDB table whose hash_key values are the authorized sender addresses"
  type        = string
}

# Agent

variable "bedrock_model_id" {
  description = "Bedrock model id used by the Strands agent"
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}
