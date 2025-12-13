# modules/ecr/main.tf

resource "aws_ecr_repository" "main" {
  name                 = var.repository_name
  image_tag_mutability = var.image_mutability
  force_delete         = true # Allows destroying the repo even if it contains images (Safe for Dev/Simulators)

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256" # Standard AWS managed encryption
  }

  tags = merge(var.tags, { Name = var.repository_name })
}

# Lifecycle Policy: Automatically cleans up old/untagged images to save money
resource "aws_ecr_lifecycle_policy" "cleanup" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}