#------------------------------------------------------------------------------
# SES inbound: domain identity + DNS for the inbound subdomain, and the
# receipt rule that stores mail in S3 then invokes the agent Lambda.
#------------------------------------------------------------------------------

data "aws_route53_zone" "main" {
  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_ses_domain_identity" "inbound" {
  domain = var.inbound_domain
}

resource "aws_route53_record" "ses_verification" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "_amazonses.${var.inbound_domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.inbound.verification_token]
}

resource "aws_ses_domain_identity_verification" "inbound" {
  domain = aws_ses_domain_identity.inbound.id

  depends_on = [aws_route53_record.ses_verification]
}

resource "aws_ses_domain_dkim" "inbound" {
  domain = aws_ses_domain_identity.inbound.domain
}

resource "aws_route53_record" "dkim" {
  count = 3

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${aws_ses_domain_dkim.inbound.dkim_tokens[count.index]}._domainkey.${var.inbound_domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.inbound.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "inbound_mx" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.inbound_domain
  type    = "MX"
  ttl     = 600
  records = ["10 inbound-smtp.${local.aws_region}.amazonaws.com"]
}

resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = local.id
}

# Only one receipt rule set can be active per account+region. Verified empty
# in this account before adopting it here; anything else added later should
# add rules to this set rather than activate a new one.
resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
}

resource "aws_ses_receipt_rule" "email_agent" {
  name          = local.id
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = [var.inbound_email_address]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.inbound_mail.id
    object_key_prefix = "inbound/"
    position          = 1
  }

  lambda_action {
    function_arn    = aws_lambda_function.email_agent.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_s3_bucket_policy.inbound_mail,
    aws_lambda_permission.ses,
  ]
}

resource "aws_lambda_permission" "ses" {
  statement_id   = "AllowSESInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.email_agent.function_name
  principal      = "ses.amazonaws.com"
  source_account = local.account_id
}
