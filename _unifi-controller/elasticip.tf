# *********************************************************
# ELASTIC IP
# *********************************************************

# Create elastic IP
resource "aws_eip" "unifi" {
    instance = aws_instance.unifi.id
    domain   = "vpc"

    tags = merge(
        var.tags,
        {
            Name = "<your resource prefix here>-${var.env_name}-${var.deployment_region_friendly}-UniFi-EIP"
        },
    )
}