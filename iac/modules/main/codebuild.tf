#------------------------------------------------------------------------------
# CodeBuild project that builds the Lambda image, pushes it to ECR, and
# updates the function (cloud equivalent of src/build_and_push.sh).
# Started on demand: aws codebuild start-build --project-name <name>
#------------------------------------------------------------------------------

locals {
  codebuild_id = "${local.id}-build"
}

resource "aws_codebuild_project" "email_agent" {
  name         = local.codebuild_id
  description  = "Builds and deploys the ${local.email_agent_id} Lambda image"
  service_role = aws_iam_role.codebuild.arn

  source {
    type            = "GITHUB"
    location        = var.source_repository_url
    git_clone_depth = 1
    buildspec       = "src/buildspec.yml"
  }

  source_version = var.git_branch

  environment {
    type         = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:6.0"

    # Required for docker build
    privileged_mode = true

    environment_variable {
      name  = "ECR_REPO_URL"
      value = aws_ecr_repository.email_agent.repository_url
    }

    environment_variable {
      name  = "FUNCTION_NAME"
      value = aws_lambda_function.email_agent.function_name
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE"]
  }

  vpc_config {
    vpc_id = data.aws_ssm_parameter.vpc_id.value

    subnets = local.private_subnets

    security_group_ids = [aws_security_group.codebuild.id]
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.codebuild_id}"
    }
  }

  tags = local.tags
}

resource "aws_security_group" "codebuild" {
  name        = local.codebuild_id
  description = "${local.codebuild_id} sg"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = local.codebuild_id
  }
}

resource "aws_iam_role" "codebuild" {
  name = local.codebuild_id

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_iam_policy" "codebuild" {
  name        = local.codebuild_id
  path        = "/"
  description = "CodeBuild service policy for ${local.codebuild_id}"

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
        "Sid" : "AllowVpc",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterfacePermission",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "iam:PassRole",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        "Resource" : ["*"]
      },
      {
        "Sid" : "EcrAuth",
        "Effect" : "Allow",
        "Action" : ["ecr:GetAuthorizationToken"],
        "Resource" : "*"
      },
      {
        "Sid" : "EcrPushPull",
        "Effect" : "Allow",
        "Action" : [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        "Resource" : aws_ecr_repository.email_agent.arn
      },
      {
        "Sid" : "UpdateLambda",
        "Effect" : "Allow",
        "Action" : [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration"
        ],
        "Resource" : aws_lambda_function.email_agent.arn
      },
      {
        "Sid" : "UseSourceConnection",
        "Effect" : "Allow",
        "Action" : [
          "codestar-connections:UseConnection",
          "codeconnections:UseConnection"
        ],
        "Resource" : data.aws_ssm_parameter.codestar_connection_arn.value
      }
    ]
  })
}
