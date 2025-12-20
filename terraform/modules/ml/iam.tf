data "aws_iam_policy_document" "assume_ecs_tasks" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ml_jobs_task_role" {
  name               = "${var.environment}-ml-jobs-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
  tags               = var.tags
}

resource "aws_iam_role" "ml_scorer_task_role" {
  name               = "${var.environment}-ml-scorer-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ml_s3_rw" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.telemetry_bucket_name}",
      "arn:aws:s3:::${var.telemetry_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "ml_s3_rw" {
  name   = "${var.environment}-ml-s3-rw"
  policy = data.aws_iam_policy_document.ml_s3_rw.json
}

resource "aws_iam_role_policy_attachment" "jobs_s3" {
  role       = aws_iam_role.ml_jobs_task_role.name
  policy_arn  = aws_iam_policy.ml_s3_rw.arn
}

resource "aws_iam_role_policy_attachment" "scorer_s3" {
  role       = aws_iam_role.ml_scorer_task_role.name
  policy_arn  = aws_iam_policy.ml_s3_rw.arn
}

data "aws_iam_policy_document" "scorer_sqs" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.model_reload.arn]
  }
}

resource "aws_iam_policy" "scorer_sqs" {
  name   = "${var.environment}-ml-scorer-sqs"
  policy = data.aws_iam_policy_document.scorer_sqs.json
}

resource "aws_iam_role_policy_attachment" "scorer_sqs_attach" {
  role      = aws_iam_role.ml_scorer_task_role.name
  policy_arn = aws_iam_policy.scorer_sqs.arn
}

# Drift needs permission to run retrain task
data "aws_iam_policy_document" "jobs_run_task" {
  statement {
    effect = "Allow"
    actions = ["ecs:RunTask"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "jobs_run_task" {
  name   = "${var.environment}-ml-jobs-run-task"
  policy = data.aws_iam_policy_document.jobs_run_task.json
}

resource "aws_iam_role_policy_attachment" "jobs_run_task_attach" {
  role       = aws_iam_role.ml_jobs_task_role.name
  policy_arn  = aws_iam_policy.jobs_run_task.arn
}

output "ml_jobs_task_role_arn" { value = aws_iam_role.ml_jobs_task_role.arn }
output "ml_scorer_task_role_arn" { value = aws_iam_role.ml_scorer_task_role.arn }
