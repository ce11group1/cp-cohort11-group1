# modules/backend-infra/main.tf

# ==============================================================================
# OPTION A: CREATE RESOURCES
# (Runs when var.create_backend_resources = true)
# ==============================================================================

resource "aws_s3_bucket" "terraform_state" {
  count         = var.create_backend_resources ? 1 : 0
  bucket        = var.bucket_name
  
  # CAUTION: 'force_destroy' allows deleting the bucket even if it has files.
  # Set to 'false' for real Production environments to prevent accidental data loss.
  force_destroy = true

  tags = merge(var.tags, {
    Name = var.bucket_name
    Role = "Terraform State Storage"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.create_backend_resources ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.create_backend_resources ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  count        = var.create_backend_resources ? 1 : 0
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(var.tags, {
    Name = var.dynamodb_table_name
    Role = "Terraform State Locking"
  })
}

# ==============================================================================
# OPTION B: READ EXISTING RESOURCES
# (Runs when var.create_backend_resources = false)
# ==============================================================================

data "aws_s3_bucket" "existing_state" {
  count  = var.create_backend_resources ? 0 : 1
  bucket = var.bucket_name
}

data "aws_dynamodb_table" "existing_locks" {
  count = var.create_backend_resources ? 0 : 1
  name  = var.dynamodb_table_name
}