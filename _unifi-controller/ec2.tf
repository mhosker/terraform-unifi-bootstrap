# *********************************************************
# EC2
# *********************************************************

data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# ---------------------------------------------------------
# Create Key Pair For EC2 Instance
# ---------------------------------------------------------

resource "aws_key_pair" "unifi" {
  key_name   = "<your resource prefix here>-${var.env_name}-${var.deployment_region_friendly}-UniFi-KeyPair"
  public_key = file("./public.key")
}

# ---------------------------------------------------------
# Create EC2 Instance
# ---------------------------------------------------------

resource "aws_instance" "unifi" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.unifi.name]

  user_data_replace_on_change = true
  user_data                   = templatefile("../_bootstrap/bootstrap.sh.tpl", {
                                  server_name       = var.server_name
                                  env_name          = var.env_name
                                  unifi_version     = var.unifi_version
                                  mongo_version     = var.mongo_version
                                  portal_https_port = local.unifi_portal_https_port
                                  portal_http_port  = local.unifi_portal_http_port
                                  bucket_name       = aws_s3_bucket.unifi.id
                                })

  iam_instance_profile = aws_iam_instance_profile.unifi.name

  key_name = aws_key_pair.unifi.key_name

  # Using this setting as the service *should* be immutable, therefore deleting the root volume automatically is desired for cleanup when rebuilding
  root_block_device {
    delete_on_termination = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.server_name}-${var.env_name}" # e.g "NAME-Prod"
    },
  )
}