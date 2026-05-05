# SecureFlow Terraform - Vulnerablilities Fixed Version.

variable "project" { type = string }

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project}-artifacts"

  tags = {
    Purpose = "CI/CD artifacts and SBOMs"
  }
}

# IV-09 fix: server-side encryption enabled
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# IV-09 fix: versioning enabled
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IV-09 fix: all public access blocked
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IV-09 fix: access logging enabled
resource "aws_s3_bucket_logging" "artifacts" {
  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = aws_s3_bucket.audit_logs.id
  target_prefix = "s3-access-logs/artifacts/"
}

resource "aws_s3_bucket" "audit_logs" {
  bucket = "${var.project}-audit-logs"
}

# IV-09 fix: server-side encryption enabled
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# IV-09 fix: versioning enabled
resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IV-09 fix: all public access blocked
resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.id
}









# SecureFlow Terraform — INTENTIONALLY VULNERABLE baseline.
# Planted vulnerabilities are tagged with their Vulnerability Index ID.

# variable "project" { type = string }

# # IV-09 — S3 buckets without server-side encryption, with public access blocks
# # disabled, and no versioning. Remediation: add aws_s3_bucket_server_side_encryption_configuration,
# # aws_s3_bucket_public_access_block with all four flags true, and aws_s3_bucket_versioning.

# resource "aws_s3_bucket" "artifacts" {
#   bucket = "${var.project}-artifacts"

#   tags = {
#     Purpose = "CI/CD artifacts and SBOMs"
#   }
# }

# # Deliberately missing: aws_s3_bucket_server_side_encryption_configuration
# # Deliberately missing: aws_s3_bucket_versioning
# # Deliberately missing: aws_s3_bucket_logging

# # IV-09 — public access block with all four flags set to false.
# resource "aws_s3_bucket_public_access_block" "artifacts" {
#   bucket = aws_s3_bucket.artifacts.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket" "audit_logs" {
#   bucket = "${var.project}-audit-logs"
# }

# # Same issues — this one will hold Falco / Vault audit output in a real deployment.
# resource "aws_s3_bucket_public_access_block" "audit_logs" {
#   bucket = aws_s3_bucket.audit_logs.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# output "artifacts_bucket" {
#   value = aws_s3_bucket.artifacts.id
# }
