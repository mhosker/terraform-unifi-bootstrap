# *********************************************************
# PROD EUW2
# *********************************************************

# ---------------------------------------------------------
# Backend
# ---------------------------------------------------------

terraform {
  backend "s3" {
    bucket  = "<your bucket here>"
    key     = "tfstate/unifi-controller-euw2-prod.tfstate"
    region  = "eu-west-2"
    profile = "<your AWS IAM profile here>"
  }
}

# ---------------------------------------------------------
# Provider Features
# ---------------------------------------------------------

provider "aws" {
  region  = "eu-west-2"
  profile = "<your AWS IAM profile here>"
}

# ---------------------------------------------------------
# Variables
# ---------------------------------------------------------

module "unifi-controller" {
  source = "../_unifi-controller"

  # ---------------------------------------------------------
  # Environment & Region
  # ---------------------------------------------------------

  env_name                   = "Prod"
  deployment_region_friendly = "EUW2"

  # ---------------------------------------------------------
  # Tags
  # ---------------------------------------------------------

  tags = {
    Environment        = "Prod"
    Service            = "UniFi Controller"
    Owner              = "<your name here>"
    Repo               = "<your repository URL here>"
    TerraformStateFile = "unifi-controller-euw2-prod.tfstate"
  }

  # ---------------------------------------------------------
  # Server Details
  # ---------------------------------------------------------

  server_name   = "<your server name here>"
  instance_type = "t3.small"
  unifi_version = "7.5.187" # Ensure url is valid using this version number e.g https://dl.ui.com/unifi/${unifi_version}/unifi_sysvinit_all.deb
  mongo_version = "4.4.24"
}