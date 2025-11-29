#######################################
# 1. IoT Thing
#######################################
resource "aws_iot_thing" "this" {
  name = var.thing_name
}

#######################################
# 2. IoT Policy (basic connect/publish/subscribe/receive)
#######################################
resource "aws_iot_policy" "this" {
  name = "${var.thing_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "iot:Connect",
          "iot:Publish",
          "iot:Receive",
          "iot:Subscribe"
        ]
        Resource = "*"
      }
    ]
  })
}

#######################################
# 3. IoT Certificate (optional)
#######################################
resource "aws_iot_certificate" "this" {
  count  = var.create_certificate ? 1 : 0
  active = true
}

#######################################
# 4. Attach Policy & Certificate to Thing
#######################################
resource "aws_iot_policy_attachment" "policy_attach" {
  count  = var.create_certificate ? 1 : 0
  policy = aws_iot_policy.this.name
  target = aws_iot_certificate.this[0].arn
}

resource "aws_iot_thing_principal_attachment" "thing_attach" {
  count     = var.create_certificate ? 1 : 0
  thing     = aws_iot_thing.this.name
  principal = aws_iot_certificate.this[0].arn
}

#######################################
# 5. IoT Topic Rule (SQL Engine)
#######################################
resource "aws_iot_topic_rule" "telemetry_rule" {
  name        = "${replace(var.thing_name, "-", "_")}_telemetry_rule"
  enabled     = true
  sql_version = "2016-03-23"

  # Example: SELECT * FROM 'cet11/grp1/telemetry'
  sql = "SELECT * FROM '${var.iot_topic}'"

  #################################
  # Optional SNS Action (matches your diagram)
  #################################
  dynamic "sns" {
    for_each = var.enable_sns_action ? [1] : []
    content {
      target_arn = var.sns_topic_arn
      role_arn   = var.sns_role_arn
    }
  }
}
