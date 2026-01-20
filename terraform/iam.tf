# IAM Role for EC2 instances with Session Manager support
resource "aws_iam_role" "ec2_session_manager" {
  name = "${var.project_name}-ec2-session-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-session-manager-role"
  }
}

# SSM Managed Instance Core policy (required for Session Manager)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_session_manager.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent policy for custom metrics
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_session_manager.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Additional policy for CloudWatch custom metrics
resource "aws_iam_role_policy" "cloudwatch_custom_metrics" {
  name = "${var.project_name}-cloudwatch-custom-metrics"
  role = aws_iam_role.ec2_session_manager.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "PeexProject/CustomMetrics"
          }
        }
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_session_manager" {
  name = "${var.project_name}-ec2-session-manager-profile"
  role = aws_iam_role.ec2_session_manager.name
}

# IAM Role for users to access Session Manager
resource "aws_iam_policy" "session_manager_access" {
  name        = "${var.project_name}-session-manager-access"
  description = "Policy for accessing EC2 instances via Session Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:ResumeSession"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/AWS-StartSSHSession"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:DescribeInstanceProperties",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus"
        ]
        Resource = "*"
      }
    ]
  })
}
