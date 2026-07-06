# #-------------------------------------------------------------------------------
# # Lambda Function which handle ai image generation.
# #-------------------------------------------------------------------------------

locals {
  email_agent_id = "${local.id}-lambda"
}

resource "aws_ecr_repository" "email_agent" { # TODO change to email_agent
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
  description   = "${local.email_agent_id} AI storybook generation"
  role          = aws_iam_role.email_agent.arn

  # Placeholder image uri
  image_uri    = "924586450630.dkr.ecr.us-east-1.amazonaws.com/ik-dev-storybook-lambda:20260226"
  package_type = "Image"

  # image_config {
  #   command = var.lambda_image_command
  # }

  timeout     = 300 # 5 minutes
  memory_size = 2048

  environment {
    variables = {
      DATA_LAKE_S3_BUCKET_NAME       = data.aws_ssm_parameter.data_lake_s3_bucket_name.value
      DATA_LAKE_S3_BUCKET_KEY_PREFIX = local.id
      STATIC_S3_BUCKET_NAME          = data.aws_ssm_parameter.static_s3_bucket_name.value
      STATIC_S3_BUCKET_KEY_PREFIX    = local.id
      CDN_DOMAIN                     = data.aws_ssm_parameter.static_s3_bucket_name.value
      FROM_EMAIL_ADDRESS             = var.ses_email_address
      GEMINI_API_KEY                 = var.gemini_api_key
    }
  }

  vpc_config {
    subnet_ids         = local.private_subnets
    security_group_ids = [aws_security_group.email_agent.id]
  }

  # lifecycle {
  #   ignore_changes = [
  #     image_uri
  #   ]
  # }
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
        "Sid" : "ListObjectsInBucket",
        "Effect" : "Allow",
        "Action" : ["s3:ListBucket"],
        "Resource" : [
          "${data.aws_ssm_parameter.data_lake_s3_bucket_arn.value}",
          "${data.aws_ssm_parameter.static_s3_bucket_arn.value}"
        ]
      },
      {
        "Sid" : "S3ReadWrite",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Resource" : [
          "${data.aws_ssm_parameter.data_lake_s3_bucket_arn.value}/${local.id}/*",
          "${data.aws_ssm_parameter.static_s3_bucket_arn.value}/${local.id}/*"
        ]
      },
      {
        Sid = "Bedrock"
        Action = [
          "bedrock:InvokeModel"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid : "AllowSendEmail",
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = "arn:aws:ses:us-east-1:924586450630:identity/ikenley.com"
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
