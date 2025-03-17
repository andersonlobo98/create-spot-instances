resource "aws_iam_role" "instance_role" {
  count = var.create_iam_role ? 1 : 0
  name  = "spot-instance-role-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "spot-instance-role-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  count = var.create_iam_role ? 1 : 0
  name  = "spot-instance-profile-${var.environment}"
  role  = aws_iam_role.instance_role[0].name
}

resource "aws_iam_role_policy" "instance_policy" {
  count = var.create_iam_role ? 1 : 0
  name  = "spot-instance-policy-${var.environment}"
  role  = aws_iam_role.instance_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:DescribeVolumes",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:DescribeSnapshots",
          "ec2:DescribeInstances",
          "ec2:CreateTags"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}