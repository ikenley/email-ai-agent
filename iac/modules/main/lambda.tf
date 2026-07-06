#-------------------------------------------------------------------------------
# Lambda Function which handles the inbound email -> agent -> reply loop.
#-------------------------------------------------------------------------------

locals {
  email_agent_id = "${local.id}-lambda"

  allowed_email_table_arn = "arn:aws:dynamodb:${local.aws_region}:${local.account_id}:table/${var.allowed_email_addresses_dynamo_table_name}"
}

resource "aws_ecr_repository" "email_agent" {
  name                 = local.email_agent_id
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "email_agent" {
  repository = aws_ecr_repository.email_agent.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 3 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 3
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

resource "aws_lambda_function" "email_agent" {
  function_name = local.email_agent_id
  description   = "${local.email_agent_id} inbound email AI agent"
  role          = aws_iam_role.email_agent.arn

  # Placeholder image uri; the real image is pushed by src/build_and_push.sh
  image_uri    = "924586450630.dkr.ecr.us-east-1.amazonaws.com/ik-dev-storybook-lambda:20260226"
  package_type = "Image"

  timeout     = 300 # 5 minutes
  memory_size = 1024

  environment {
    variables = {
      INBOUND_MAIL_BUCKET = aws_s3_bucket.inbound_mail.id
      ALLOWED_EMAIL_TABLE = var.allowed_email_addresses_dynamo_table_name
      BEDROCK_MODEL_ID    = var.bedrock_model_id
      AGENT_EMAIL_ADDRESS = var.inbound_email_address
    }
  }

  vpc_config {
    subnet_ids         = local.private_subnets
    security_group_ids = [aws_security_group.email_agent.id]
  }

  lifecycle {
    ignore_changes = [
      image_uri
    ]
  }

  tags = local.tags
}

# SES invokes the Lambda asynchronously; without this, a failure after the
# Bedrock call would retry the whole email and could send duplicate replies.
resource "aws_lambda_function_event_invoke_config" "email_agent" {
  function_name          = aws_lambda_function.email_agent.function_name
  maximum_retry_attempts = 0
}

resource "aws_iam_role" "email_agent" {
  name = local.email_agent_id

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "email_agent" {
  role       = aws_iam_role.email_agent.name
  policy_arn = aws_iam_policy.email_agent.arn
}

resource "aws_iam_policy" "email_agent" {
  name        = local.email_agent_id
  path        = "/"
  description = "Lambda execution policy for ${local.email_agent_id}"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowLogging",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "AllowVpcAccess",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "ReadInboundMail",
        "Effect" : "Allow",
        "Action" : ["s3:GetObject"],
        "Resource" : "${aws_s3_bucket.inbound_mail.arn}/inbound/*"
      },
      {
        "Sid" : "ReadAllowedEmailAddresses",
        "Effect" : "Allow",
        "Action" : ["dynamodb:GetItem"],
        "Resource" : local.allowed_email_table_arn
      },
      {
        "Sid" : "Bedrock",
        "Effect" : "Allow",
        "Action" : [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "AllowSendEmail",
        "Effect" : "Allow",
        "Action" : [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        "Resource" : aws_ses_domain_identity.inbound.arn
      }
    ]
  })
}

#------------------------------------------------------------------------------
# Lambda security group
#------------------------------------------------------------------------------

resource "aws_security_group" "email_agent" {
  name        = "${local.email_agent_id}-sg"
  description = "${local.email_agent_id} security group"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
}

resource "aws_security_group_rule" "email_agent_egress_https" {
  security_group_id = aws_security_group.email_agent.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
