# *********************************************************
# S3
# *********************************************************

# ---------------------------------------------------------
# Create Bucket
# ---------------------------------------------------------

resource "aws_s3_bucket" "unifi" {
    bucket = lower("<your resource prefix here>${var.env_name}${var.deployment_region_friendly}UniFi")

    tags = merge(
        var.tags,
        {
            Name = lower("<your resource prefix here>${var.env_name}${var.deployment_region_friendly}UniFi")
        },
    )
}

# ---------------------------------------------------------
# Create Folders Within Bucket
# ---------------------------------------------------------

locals{
    bucket_folders = ["backups"]
}

resource "aws_s3_object" "unifi" {
    for_each = toset(local.bucket_folders)

    bucket = aws_s3_bucket.unifi.id
    key    = "${each.value}/"
    acl    = "private"
}