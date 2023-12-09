# *********************************************************
# IAM
# *********************************************************

# ---------------------------------------------------------
# Create Role
# ---------------------------------------------------------

# EC2 is allowed to assume this role
resource "aws_iam_role" "unifi" {
    name                  = "<your resource prefix here>-${var.env_name}-UniFi-Role"
    assume_role_policy    = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        },
        ]
    })
    force_detach_policies = true 
}

# ---------------------------------------------------------
# Add Inline Policy To Role
# ---------------------------------------------------------

# This policy allows least privilege read / write on the UniFi bucket
resource "aws_iam_role_policy" "unifi" {
    name     = aws_iam_role.unifi.id
    role     = aws_iam_role.unifi.id
    policy   = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = [
                "s3:ListBucket"
            ]
            Effect   = "Allow"
            Resource = "${aws_s3_bucket.unifi.arn}"
        },
        {
            Action = [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ]
            Effect   = "Allow"
            Resource = "${aws_s3_bucket.unifi.arn}/*"
        },
        ]
    })
}

# ---------------------------------------------------------
# Create Instance Profile
# ---------------------------------------------------------

resource "aws_iam_instance_profile" "unifi" {
  name = aws_iam_role.unifi.id
  role = "${aws_iam_role.unifi.name}"
}