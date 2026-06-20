provider "aws" {
  region  = "ap-south-1"
  profile = var.aws_profile
}

resource "aws_s3_bucket" "terraform_backend" {
  bucket = "sandbox-liju-terraform-backend"
}

resource "aws_s3_bucket_versioning" "terraform_backend" {
  bucket = aws_s3_bucket.terraform_backend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_backend" {
  bucket = aws_s3_bucket.terraform_backend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
