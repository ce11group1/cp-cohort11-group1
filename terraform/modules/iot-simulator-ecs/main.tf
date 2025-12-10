# modules/iot-simulator-ecs/main.tf

data "aws_secretsmanager_secret" "grafana_smtp" {
  name = "grafana/smtp"
}

resource "aws_cloudwatch_log_group" "logs" {
  name = "/ecs/iot-simulator"
  retention_in_days = var.environment == "prod" ? 90 : 7
  tags = merge(var.tags, { Name = "${var.environment}-iot-logs" })
}

resource "aws_ecs_task_definition" "main" {
  family                   = "iot-simulator-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 3072
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  # Shared volumes to hold downloaded configs
  volume { name = "config-volume" }
  volume { name = "certs-volume" }

container_definitions = jsonencode([
    # --- 1. INIT CONTAINER ---
    {
      name      = "init-s3-downloader"
      image     = "amazon/aws-cli:latest"
      essential = false
      entryPoint = ["/bin/sh", "-c"],
      mountPoints = [
        { sourceVolume = "config-volume", containerPath = "/mnt/config" },
        { sourceVolume = "certs-volume",  containerPath = "/mnt/certs" }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = { "awslogs-group" = aws_cloudwatch_log_group.logs.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = "init" }
      }
      # command = [
      #   <<-EOT
      #     echo "Starting S3 Download..."
          
      #     # 1. Certs: Download to /mnt/certs/ (Root of volume)
      #     aws s3 cp s3://${var.cert_bucket}/ /mnt/certs/ --recursive --exclude "*" --include "*.pem" --include "*.crt" --include "*.key"
          
      #     # 2. Prometheus: Download DIRECTLY to root of config volume
      #     # Destination MUST be /mnt/config/prometheus.yml
      #     aws s3 cp s3://${var.config_bucket}/prometheus/prometheus.yml /mnt/config/prometheus.yml
          
      #     # 3. Grafana: Download provisioning folder to /mnt/config/provisioning
      #     aws s3 cp s3://${var.config_bucket}/grafana/provisioning/ /mnt/config/provisioning/ --recursive
          
      #     # 4. Grafana Config: Move grafana.ini to root /mnt/config/grafana.ini
      #     # We try to copy it from two possible download locations just to be safe
      #     cp /mnt/config/provisioning/grafana.ini /mnt/config/grafana.ini || cp /mnt/config/grafana/grafana.ini /mnt/config/grafana.ini || echo "Warning: grafana.ini not moved"

      #     # 5. DEBUG: List files so we can see them in logs if it fails
      #     echo "Listing /mnt/config:"
      #     ls -R /mnt/config
          
      #     chmod -R 777 /mnt/config /mnt/certs
      #     echo "Download Complete."
      #   EOT
      # ]
      # command = [
      #   <<-EOT
      #     echo "Starting S3 Download..."
          
      #     # 1. Download Files
      #     aws s3 cp s3://${var.cert_bucket}/ /mnt/certs/ --recursive --exclude "*" --include "*.pem" --include "*.crt" --include "*.key"
      #     aws s3 cp s3://${var.config_bucket}/grafana/provisioning/ /mnt/config/provisioning/ --recursive
      #     aws s3 cp s3://${var.config_bucket}/prometheus/prometheus.yml /mnt/config/prometheus.yml

      #     # 2. CONFIG FIX: Move grafana.ini to root
      #     cp /mnt/config/provisioning/grafana.ini /mnt/config/grafana.ini || cp /mnt/config/grafana/grafana.ini /mnt/config/grafana.ini || echo "Warning: grafana.ini not moved"
          
      #     # 3. NETWORK FIX: Rewrite hostnames for Fargate (Localhost)
      #     # In Fargate sidecars, 'prometheus' and 'iot-simulator' are just 'localhost'
      #     echo "Rewriting config files for ECS Localhost..."
      #     sed -i 's/iot-simulator/localhost/g' /mnt/config/prometheus.yml
      #     sed -i 's/prometheus:9090/localhost:9090/g' /mnt/config/provisioning/datasources/*.yaml || true
      #     sed -i 's/prometheus:9090/localhost:9090/g' /mnt/config/provisioning/datasources/*.yml || true

      #     # 4. CRASH FIX: Force remove complex alerting rules that might break startup
      #     rm -rf /mnt/config/provisioning/alerting/notification-policies.yaml
          
      #     # 5. PERMISSION FIX: Give ownership to Grafana (User 472)
      #     chown -R 472:472 /mnt/config
      #     chown -R 65534:65534 /mnt/config/prometheus.yml
      #     chmod -R 777 /mnt/certs
          
      #     echo "Setup Complete."
      #   EOT
      # ]
command = [
        <<-EOT
          echo "Starting Setup..."
          
          # 1. Download Files
          aws s3 cp s3://${var.cert_bucket}/ /mnt/certs/ --recursive --exclude "*" --include "*.pem" --include "*.crt" --include "*.key"
          aws s3 cp s3://${var.config_bucket}/grafana/provisioning/ /mnt/config/provisioning/ --recursive

          # 2. FORCE-WRITE PROMETHEUS CONFIG (Safe Method)
          echo "Creating Fargate-compatible prometheus.yml..."
          {
            echo "global:"
            echo "  scrape_interval: 15s"
            echo "scrape_configs:"
            echo "  - job_name: 'prometheus'"
            echo "    metrics_path: '/prometheus/metrics'"   # <--- FIX 1: Look in the new sub-path
            echo "    static_configs:"
            echo "      - targets: ['localhost:9090']"
            echo "  - job_name: 'iot-simulator'"
            echo "    static_configs:"
            echo "      - targets: ['localhost:9100']"
          } > /mnt/config/prometheus.yml

          # 3. FORCE-WRITE DATASOURCE (Safe Method)
          echo "Creating Fargate-compatible datasource..."
          {
            echo "apiVersion: 1"
            echo "datasources:"
            echo "  - name: Prometheus"
            echo "    type: prometheus"
            echo "    uid: prometheus"         # <--- THIS IS THE KEY FIX
            echo "    access: proxy"
            echo "    url: http://localhost:9090/prometheus" # <--- FIX 2: Grafana must talk to Prom at sub-path
            echo "    isDefault: true"
          } > /mnt/config/provisioning/datasources/datasources.yaml

          # 4. CLEANUP & PERMISSIONS
          cp /mnt/config/provisioning/grafana.ini /mnt/config/grafana.ini || echo "No custom ini found"
          
          # Remove alerting to prevent crashes
          rm -rf /mnt/config/provisioning/alerting/notification-policies.yaml

          # CRITICAL: Fix Permissions
          chown -R 472:472 /mnt/config
          chown -R 65534:65534 /mnt/config/prometheus.yml
          chmod -R 777 /mnt/certs
          
          echo "Setup Complete."
        EOT
      ]
    },

    # --- 2. IOT SIMULATOR ---
    {
      name      = "iot-simulator"
      image     = "${var.repository_url}:latest"
      essential = true
      dependsOn = [{ containerName = "init-s3-downloader", condition = "SUCCESS" }]
      mountPoints = [
        { sourceVolume = "certs-volume", containerPath = "/app/certs" }
      ]
      environment = [
        # --- FIX 2: Rename IOT_ENDPOINT to AWS_ENDPOINT ---
        { name = "AWS_ENDPOINT", value = var.iot_endpoint },
        { name = "DEVICE_ID",    value = "iot-sim-device-001" }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = { "awslogs-group" = aws_cloudwatch_log_group.logs.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = "app" }
      }
    },

    # --- 3. PROMETHEUS (Unchanged) ---
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      essential = true
      dependsOn = [{ containerName = "init-s3-downloader", condition = "SUCCESS" }]
      portMappings = [{ containerPort = 9090, hostPort = 9090 }]
      mountPoints = [
        { sourceVolume = "config-volume", containerPath = "/etc/prometheus" }
      # This maps /mnt/config (host) -> /etc/prometheus (container)
      # So /mnt/config/prometheus.yml becomes /etc/prometheus/prometheus.yml (CORRECT)
      ]
      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--web.listen-address=:9090",
        "--web.external-url=/prometheus/",
        "--web.route-prefix=/prometheus/"
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.logs.name,
          "awslogs-region"        = var.region,
          "awslogs-stream-prefix" = "prom"
        }
      }
    },

    # --- 4. GRAFANA (Unchanged) ---
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      essential = true
      dependsOn = [{ containerName = "init-s3-downloader", condition = "SUCCESS" }]
      portMappings = [{ containerPort = 3000, hostPort = 3000 }]
      mountPoints = [
        { sourceVolume = "config-volume", containerPath = "/etc/grafana" }
      # This maps /mnt/config (host) -> /etc/grafana (container)
      # So /mnt/config/grafana.ini becomes /etc/grafana/grafana.ini (CORRECT)
      ]
      command = [
        "--config=/etc/grafana/grafana.ini",
        "--homepath=/usr/share/grafana",
        "--packaging=docker"
      ]
      secrets = [
        { name = "GF_SMTP_HOST",         valueFrom = "${data.aws_secretsmanager_secret.grafana_smtp.arn}:SMTP_HOST::" },
        { name = "GF_SMTP_USER",         valueFrom = "${data.aws_secretsmanager_secret.grafana_smtp.arn}:SMTP_USER::" },
        { name = "GF_SMTP_PASSWORD",     valueFrom = "${data.aws_secretsmanager_secret.grafana_smtp.arn}:SMTP_PASSWORD::" },
        { name = "GF_SMTP_FROM_ADDRESS", valueFrom = "${data.aws_secretsmanager_secret.grafana_smtp.arn}:SMTP_FROM::" },
        { name = "GF_SMTP_FROM_NAME",    valueFrom = "${data.aws_secretsmanager_secret.grafana_smtp.arn}:SMTP_NAME::" }
      ]
      environment = [
        { name = "GF_SECURITY_ADMIN_USER",     value = "admin" },
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = "admin" },
        { name = "GF_SMTP_ENABLED",            value = "true" },
        { name = "GF_SMTP_SKIP_VERIFY",        value = "true" },
        { name = "GF_SMTP_STARTTLS_POLICY",    value = "OpportunisticStartTLS" }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = { "awslogs-group" = aws_cloudwatch_log_group.logs.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = "grafana" }
      }
    }
  ])
}

# =========================================================
# LOAD BALANCER CONNECTION
# =========================================================

# Target Group: Defines WHERE to send traffic (to Grafana container)
resource "aws_lb_target_group" "grafana" {
  name        = "${var.name_prefix}-graf-tg"
  port        = 3000            # Traffic arrives at TG on port 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"            # REQUIRED for Fargate

  health_check {
    path                = "/api/health" # Grafana specific health check
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener Rule: Defines WHEN to send traffic to this Target Group
resource "aws_lb_listener_rule" "grafana_rule" {
  listener_arn = var.alb_listener_arn
  priority     = 100 # Priority 100 (Lambda can use 200, etc.)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    path_pattern {
      values = ["/*"] # Send ALL traffic to Grafana (Modify if sharing with Lambda)
    }
  }
}

# Target Group: Prometheus
resource "aws_lb_target_group" "prometheus" {
  name        = "${var.name_prefix}-prom-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/prometheus/-/healthy"   # Prometheus health endpoint
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener Rule: Prometheus
resource "aws_lb_listener_rule" "prometheus_rule" {
  listener_arn = var.alb_listener_arn
  priority     = 90

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }

  condition {
    path_pattern {
      values = ["/prometheus/*"]
    }
  }
}

# Security Rule: Allow the ALB to talk to ECS
# We append this rule to the EXISTING security group passed in var.security_groups[0]
# OR we can create a new SG rule if we know the ID. 
# SIMPLER APPROACH: Create a dedicated SG rule resource attached to the ECS SG.
# (Assuming var.security_groups contains at least one SG ID created elsewhere)

resource "aws_security_group_rule" "allow_alb_ingress" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id # Allow only ALB
  security_group_id        = var.security_groups[0]    # Attach to the Task SG
}

# Security Rule: Allow ALB to talk to Prometheus
resource "aws_security_group_rule" "allow_alb_ingress_prometheus" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = var.security_groups[0]
}


# ECS Service: Attach Prometheus container

resource "aws_ecs_service" "main" {
  name            = "${var.environment}-iot-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # --- NEW BLOCK ---
  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana" # MUST match the name in container_definitions
    container_port   = 3000      # MUST match the container port
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  # -----------------

# Single NAT Gateway (Cost vs. Reliability)
# The Observation: You are currently putting ECS tasks in Public Subnets (assigning public IPs).
# The Improvement: For a production enterprise setup, resources usually live in Private Subnets with a NAT Gateway.
# Prod: Private Subnets + NAT Gateway (More secure, higher cost).
# Dev: Public Subnets (Cheaper, easier access).
  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = true       # Set to false if using Private Subnets + NAT Gateway
  }
  
  # Wait for the rule to be ready before creating service
    depends_on = [
    aws_lb_listener_rule.grafana_rule,
    aws_lb_listener_rule.prometheus_rule
  ]
  tags = merge(var.tags, { Name = "${var.environment}-iot-service" })
}