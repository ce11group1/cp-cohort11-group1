#############################################
# IoT MODULE — cet11-grp1
#############################################
#############################################
# Thing + Certificate + Policy
#############################################

resource "aws_iot_thing" "device" {
  name = "${var.prefix}-${var.env}-device"
}

resource "aws_iot_policy" "policy" {
  name = "${var.prefix}-${var.env}_iot_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "iot:Connect",
        "iot:Publish",
        "iot:Subscribe",
        "iot:Receive"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iot_certificate" "cert" {
  active = true
}

resource "aws_iot_policy_attachment" "attach_policy" {
  policy = aws_iot_policy.policy.name
  target = aws_iot_certificate.cert.arn
}

resource "aws_ssm_parameter" "cert" {
  name  = "/iot/${var.prefix}/${var.env}/cert"
  type  = "SecureString"
  value = aws_iot_certificate.cert.certificate_pem
}

resource "aws_ssm_parameter" "key" {
  name  = "/iot/${var.prefix}/${var.env}/key"
  type  = "SecureString"
  value = aws_iot_certificate.cert.private_key
}

#############################################
# IoT Rule → S3 Optimized Time Partitioning
#############################################

resource "aws_iot_topic_rule" "topic_rule" {
  name        = "${replace(var.prefix, "-", "_")}_${var.env}_iot_rule"
  description = "IoT rule storing raw telemetry in optimized S3 structure"
  enabled     = true

  sql         = "SELECT *, clientid() as device_id FROM '${var.prefix}/${var.env}/data'"
  sql_version = "2016-03-23"

  s3 {
    role_arn    = aws_iam_role.iot_s3_role.arn
    bucket_name = var.s3_bucket

    key = "raw-data/timestamp=$${timestamp()}/device=$${clientId()}.json"

    canned_acl = "private"
  }


}

#############################################
# IAM Role + Policy for IoT → S3
#############################################

resource "aws_iam_role" "iot_s3_role" {
  name = "${var.prefix}-${var.env}-iot-s3-role"

  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "iot.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "iot_s3_policy" {
  name = "${var.prefix}-${var.env}-iot-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:PutObject"],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}/raw-data/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iot_s3_attach" {
  role       = aws_iam_role.iot_s3_role.name
  policy_arn = aws_iam_policy.iot_s3_policy.arn
}
