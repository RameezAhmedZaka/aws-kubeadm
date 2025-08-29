# -------------------
# Manager IAM Role and Policies
# -------------------

resource "aws_iam_role" "manager_ssm_role" {
  name = var.manager_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy" "manager_custom_ssm_policy" {
  name = "${var.manager_role_name}-custom-policy"
  role = aws_iam_role.manager_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ssm:DescribeInstanceInformation",
          "ssm:DescribeDocument",
          "ssm:GetDocument",
          "ssm:StartSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus",
          "ssm:TerminateSession"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["ec2:DescribeInstances"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ],
        Resource = "*"  # Can be restricted to specific secret ARNs if desired
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "manager_ssm_core_attachment" {
  role       = aws_iam_role.manager_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "manager_ssm_instance_profile" {
  name = var.manager_profile_name
  role = aws_iam_role.manager_ssm_role.name
}

# -------------------
# Node IAM Role and Policies
# -------------------

resource "aws_iam_role" "node_ssm_role" {
  name = var.node_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy" "node_limited_ssm_policy" {
  name = "${var.node_role_name}-limited-policy"
  role = aws_iam_role.node_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach AmazonSSMManagedInstanceCore for full SSM connectivity
resource "aws_iam_role_policy_attachment" "node_ssm_core_attachment" {
  role       = aws_iam_role.node_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node_ssm_instance_profile" {
  name = var.node_profile_name
  role = aws_iam_role.node_ssm_role.name
}
