# *********************************************************
# VARIABLES
# *********************************************************
# ---------------------------------------------------------
# Environment & Region
# ---------------------------------------------------------

variable "env_name" {
  type        = string
  description = "The name of the environemnt being deployed. e.g Prod, Dev, Test"
  nullable    = false
}

variable "deployment_region_friendly" {
  type = string
  description = "The friendly name of the region being deployed to. e.g EUW2"
  nullable = false
}

# ---------------------------------------------------------
# Tags
# ---------------------------------------------------------

variable "tags" {
  type = object({
    Environment        = string
    Service            = string
    Owner              = string
    Repo               = string
    TerraformStateFile = string
  })
  description = "AWS tags to be applied to all resources."
  nullable    = false
}

# ---------------------------------------------------------
# Server Details
# ---------------------------------------------------------

variable "server_name" {
  type        = string
  description = "The name of the server being deployed."
  nullable    = false
}

variable "instance_type" {
  type        = string
  description = "The name of AWS instance type. e.g t3.micro"
  nullable    = false
}

variable "unifi_version" {
  type        = string
  description = "Version of UniFi to install. e.g 7.5.174"
  nullable    = false
}

variable "mongo_version" {
  type        = string
  description = "Version of MongoDB to install. e.g 4.4.24"
  nullable    = false
}