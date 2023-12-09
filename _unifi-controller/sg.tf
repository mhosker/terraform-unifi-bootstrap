# *********************************************************
# SECURITY GROUPS
# *********************************************************

# ---------------------------------------------------------
# Get CloudFlare IPs
# ---------------------------------------------------------

data "http" "cloudflare_ips_v4" {
  url    = "https://www.cloudflare.com/ips-v4"
  method = "GET"
}

data "http" "cloudflare_ips_v6" {
  url    = "https://www.cloudflare.com/ips-v6"
  method = "GET"
}

# ---------------------------------------------------------
# Set Locals
# ---------------------------------------------------------

locals{
    # UniFi portal https port default is 8843 however this is not supported by CloudFlare. 
    # So we used a CloudFlare proxy supported port being 2083.
    # This gets changed in the ec2 bootstrap by editing the UniFi system.properties file.
    # A security group rule also gets added inbound for this port TCP from CloudFlare IPs.
    # NOTE: Cannot use ports lower than 1024, this is due to the UniFi service not running as root so cannot bind to priveleged ports (<1024)
    unifi_portal_https_port = 2083
    unifi_portal_http_port  = 8880 # 8880 is UniFi default & supported for CloudFlare HTTP proxy
    
    # These are the UniFi default ports that need to be allowed in the ec2 security group rules
    unifi_mgmt_ports   = ["8443_tcp"] # Used for application GUI/API as seen in a web browser.
    unifi_public_ports = ["8080_tcp", # Used for device and application communication.
                          "3478_udp"] # Used for STUN.

    admin_mgmt_cidr = "<your administration CIDR here>"

    # CloudFlare formatted IP lists
    cloudflare_ips_v4 = split("\n", data.http.cloudflare_ips_v4.response_body)
    cloudflare_ips_v6 = split("\n", data.http.cloudflare_ips_v6.response_body)
}

# ---------------------------------------------------------
# Create Security Group
# ---------------------------------------------------------

resource "aws_security_group" "unifi" {
    name        = "<your resource prefix here>-${var.env_name}-${var.deployment_region_friendly}-UniFi-SG"
    description = "UniFi rules inc mgmt via CloudFlare. Unrestricted outbound."

    # Administration SSH
    ingress {
        description = "22 MGMT Administration tcp"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [local.admin_mgmt_cidr]
    }

    # Administration MGMT ports rules
    dynamic "ingress" {
        for_each = {for v in local.unifi_mgmt_ports : v => {ports = split("_", v)[0], protocol = split("_", v)[1]}}
        content {
            description = "${ingress.value.ports} MGMT Administration ${ingress.value.protocol}"
            from_port   = length(regexall("-", ingress.value.ports)) > 0 ? split("-", ingress.value.ports)[0] : ingress.value.ports
            to_port     = length(regexall("-", ingress.value.ports)) > 0 ? split("-", ingress.value.ports)[1] : ingress.value.ports
            protocol    = ingress.value.protocol
            cidr_blocks = [local.admin_mgmt_cidr]
        }
    }

    # CloudFlare MGMT ports rules
    dynamic "ingress" {
        for_each = {for v in local.unifi_mgmt_ports : v => {ports = split("_", v)[0], protocol = split("_", v)[1]}}
        content {
            description      = "${ingress.value.ports} MGMT CloudFlare ${ingress.value.protocol}"
            from_port        = length(regexall("-", ingress.value.ports)) > 0 ? split("-", ingress.value.ports)[0] : ingress.value.ports
            to_port          = length(regexall("-", ingress.value.ports)) > 0 ? split("-", ingress.value.ports)[1] : ingress.value.ports
            protocol         = ingress.value.protocol
            cidr_blocks      = local.cloudflare_ips_v4
            ipv6_cidr_blocks = local.cloudflare_ips_v6
        }
    }

    # CloudFlare GuestPortal ports rules
    dynamic "ingress" {
        for_each = [local.unifi_portal_https_port, local.unifi_portal_http_port]
        content {
            description      = "${ingress.value} GuestPortal CloudFlare tcp"
            from_port        = ingress.value
            to_port          = ingress.value
            protocol         = "tcp"
            cidr_blocks      = local.cloudflare_ips_v4
            ipv6_cidr_blocks = local.cloudflare_ips_v6
        }
    }

    # Public ports rules
    dynamic "ingress" {
        for_each = {for v in local.unifi_public_ports : v => {ports = split("_", v)[0], protocol = split("_", v)[1]}}
        content {
            description      = "${ingress.value.ports} Public ${ingress.value.protocol}"
            from_port        = length(regexall("-", ingress.value.ports)) > 0 ? split("-", ingress.value.ports)[0] : ingress.value.ports
            to_port          = length(regexall("-", ingress.value.ports)) > 0 ? split("-", ingress.value.ports)[1] : ingress.value.ports
            protocol         = ingress.value.protocol
            cidr_blocks      = ["0.0.0.0/0"]
            ipv6_cidr_blocks = ["::/0"]
        }
    }

    # Out to anywhere
    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }

    tags = merge(
        var.tags,
        {
            Name = "<your resource prefix here>-${var.env_name}-${var.deployment_region_friendly}-UniFi-SG"
        },
    )
}