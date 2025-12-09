#############################################
# Locals — 80% thresholds for "high" alerts
#############################################

locals {
  temperature_80 = var.temperature_max * 0.80
  humidity_80    = var.humidity_max * 0.80
  pressure_80    = var.pressure_max * 0.80
  battery_80     = var.battery_max * 0.80
}

#############################################
# SNS Topic + Email Subscription
#############################################

resource "aws_sns_topic" "iot_alerts" {
  name = "${var.prefix}-${var.env}-iot-alerts"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.iot_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

#############################################
# Lambda IAM Role & Policy
#############################################

resource "aws_iam_role" "lambda_role" {
  name = "${var.prefix}-${var.env}-iot-alert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.prefix}-${var.env}-iot-alert-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.iot_alerts.arn
      }
    ]
  })
}

#############################################
# Lambda Function
#############################################

resource "aws_lambda_function" "alert_handler" {
  function_name = "${var.prefix}-${var.env}-iot-alert-handler"
  role          = aws_iam_role.lambda_role.arn

  filename    = "${path.module}/lambda_src/lambda.zip"
  handler     = "handler.lambda_handler"
  runtime     = "python3.9"
  timeout     = 10
  memory_size = 256

  source_code_hash = filebase64sha256("${path.module}/lambda_src/lambda.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.iot_alerts.arn
      PREFIX        = var.prefix
      ENV           = var.env
    }
  }
}


#############################################
# Allow IoT Core to invoke Lambda
#############################################

resource "aws_lambda_permission" "allow_iot" {
  statement_id  = "AllowIotInvoke_${var.env}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_handler.function_name
  principal     = "iot.amazonaws.com"
}

#############################################
# IoT Topic Rule — fires ONLY on threshold breach
#############################################

resource "aws_iot_topic_rule" "threshold_rule" {
  name        = "${replace(var.prefix, "-", "_")}_${var.env}_threshold_rule"
  description = "Trigger Lambda only on TRUE anomalies"
  enabled     = true

  sql = <<EOF
SELECT *
FROM '${var.iot_topic}'
WHERE
     temperature > ${var.temperature_max}
  OR humidity    > ${var.humidity_max}
  OR pressure    > ${var.pressure_max}
  OR battery     < ${var.battery_min}
EOF

  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.alert_handler.arn
  }

  depends_on = [
    aws_lambda_function.alert_handler
  ]
}

