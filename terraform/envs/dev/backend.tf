# STEP 1: COMMENT EVERYTHING BELOW THIS LINE FOR THE FIRST "TERRAFORM APPLY"
# STEP 2: RUN 'terraform apply' to create the bucket.
# STEP 3: UNCOMMENT BELOW, AND RUN 'terraform init' TO MIGRATE STATE.
# -----------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "grp1-ce11-dev-iot-state-bucket" # <--- UPDATE THIS AFTER 1st RUN to match your variables
    key            = "grp1-ce11-dev-iot/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "grp1-ce11-dev-iot-locks"       # <--- UPDATE THIS AFTER 1st RUN
    encrypt        = true
  }
}