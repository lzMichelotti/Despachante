# who am i?
data "aws_caller_identity" "current" {}


# The bucket. Dev and prod state files live here.
resource "aws_s3_bucket" "state" {
  bucket = "despachante-shared-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = {
    Component = "tfstate"
  }
}


# Versioning: every write creates a new version instead of overwriting.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# All four fields. S3 has four different paths to public exposure:
# two through ACLs (legacy) and two through bucket policy.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
