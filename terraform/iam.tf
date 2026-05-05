# ── EC2 Instance Role ──────────────────────────────────────────
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect="Allow", Principal={ Service="ec2.amazonaws.com" }, Action="sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.project_name}-ec2-policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = ["ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:BatchCheckLayerAvailability","ecr:PutImage","ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload"]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData","cloudwatch:GetMetricData"]
        Resource = "*"
        Condition = { StringEquals = { "cloudwatch:namespace" = "${var.project_name}/app-metrics" } }
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/${var.project_name}/*"
      },
      {
        Sid    = "SSMAgent"
        Effect = "Allow"
        Action = ["ssm:UpdateInstanceInformation","ssmmessages:CreateControlChannel","ssmmessages:CreateDataChannel","ssmmessages:OpenControlChannel","ssmmessages:OpenDataChannel"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ── Lambda Rollback Role ────────────────────────────────────────
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect="Allow", Principal={ Service="lambda.amazonaws.com" }, Action="sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-rollback:*"
      },
      {
        Sid    = "SSMSendCommand"
        Effect = "Allow"
        Action = ["ssm:SendCommand"]
        # Restrict to only EC2 instances tagged with our project
        Resource = ["arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"]
        Condition = { StringEquals = { "ssm:resourceTag/Project" = var.project_name } }
      },
      {
        Sid      = "SSMDocument"
        Effect   = "Allow"
        Action   = ["ssm:SendCommand"]
        Resource = "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"
      },
      {
        Sid    = "SSMStatus"
        Effect = "Allow"
        Action = ["ssm:GetCommandInvocation"]
        Resource = "*"
      }
    ]
  })
}

# ── GitHub Actions OIDC Role (no long-lived keys!) ──────────────
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "github_actions_role" {
  name = "${var.project_name}-github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_policy" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = ["ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:BatchCheckLayerAvailability","ecr:PutImage","ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload"]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "SSMDeploy"
        Effect = "Allow"
        Action = ["ssm:SendCommand","ssm:GetCommandInvocation","ssm:WaitCommandExecuted"]
        Resource = "*"
      }
    ]
  })
}