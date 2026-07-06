#------------------------------------------------------------------------------
# S3 bucket where SES stores raw inbound mail. Messages are throwaway once
# processed, so everything expires after 30 days.
#------------------------------------------------------------------------------

resource "aws_s3_bucket" "inbound_mail" {
  bucket = "${local.account_id}-${local.id}-inbound"

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "inbound_mail" {
  bucket = aws_s3_bucket.inbound_mail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "inbound_mail" {
  bucket = aws_s3_bucket.inbound_mail.id

  rule {
    id     = "expire-inbound-mail"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "inbound_mail" {
  bucket = aws_s3_bucket.inbound_mail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESPut"
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.inbound_mail.arn}/inbound/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:ses:${local.aws_region}:${local.account_id}:receipt-rule-set/${local.id}:receipt-rule/*"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.inbound_mail]
}
