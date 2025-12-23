# IoT Factory Simulator – Capstone Project

## 1. Executive Summary

This project is a cloud-native **IoT Factory Simulator** designed to generate, transmit, store, and visualize real-time telemetry data. The infrastructure allows for scalable device simulation using **AWS IoT Core** for connectivity and **ECS Fargate** for compute, while leveraging **Prometheus** and **Grafana** for observability. The entire stack is provisioned using **Terraform** (Infrastructure as Code) to ensure reproducibility and modularity.

---

## 2. System Architecture

The architecture follows a microservices approach deployed on AWS. The system is divided into three main logical layers: **Connectivity (IoT)**, **Compute (ECS)**, and **Storage/Observability**.

### High-Level Architecture (Conceptual)

Core Components:

- **VPC Network:**  
  A custom VPC with public subnets spanning multiple Availability Zones for high availability.

- **IoT Core:**  
  Managed MQTT broker acting as the entry point for device data.

- **ECS Fargate Cluster:**  
  Serverless container orchestration running the simulator application and monitoring stack side-by-side.

- **Application Load Balancer (ALB):**  
  Provides an HTTP entry point for accessing the Grafana dashboard.

- **S3 Storage:**  
  Used for long-term data archiving (cold storage) and configuration management.

---

## 3. Technology Stack & Resources Used

| Resource / Tool | Technology          | Reason for Selection (Justification)                                                                                           |
| --------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| IaC             | Terraform           | Modular infrastructure management; state locking via DynamoDB ensures team collaboration safety.                               |
| Compute         | AWS ECS (Fargate)   | Serverless container execution removes the need to manage EC2 instances/OS patching; supports sidecar containers (Prometheus). |
| Connectivity    | AWS IoT Core        | Fully managed MQTT broker that handles mutual TLS authentication and scales automatically to millions of messages.             |
| Storage         | AWS S3              | Cost-effective storage for telemetry logs (via IoT Rules) and dynamic configuration files for the containers.                  |
| Visualization   | Grafana             | Industry-standard visualization tool; deployed as a container to provide custom dashboards for IoT metrics.                    |
| Monitoring      | Prometheus          | Scrapes metrics from the simulator application locally within the ECS task, ensuring low latency monitoring.                   |
| Networking      | AWS ALB             | Distributes incoming traffic to the Grafana container and provides a static DNS endpoint.                                      |
| Security        | AWS Secrets Manager | Securely manages sensitive credentials (SMTP passwords for Grafana alerts) without hardcoding them in Terraform.               |

---

## 4. Technical Deep Dive

### 4.1. ECS Fargate Task Architecture

The application runs as a single ECS Task containing four tightly coupled containers using the **Sidecar** pattern.

- **Init Container (`init-s3-downloader`):**  
  Runs pre-boot to download certificates and configurations (Grafana dashboards, Prometheus YAMLs) from S3 to a shared volume. It handles dynamic configuration injections at runtime.

- **App Container (`iot-simulator`):**  
  The core Python script that connects to AWS IoT Core via MQTT (Port 8883) using X.509 certificates.

- **Prometheus Container:**  
  Scrapes metrics from `localhost:9100` and stores them in memory.

- **Grafana Container:**  
  Reads provisioned dashboards from the shared volume and queries `localhost:9090` (Prometheus) for time-series data.

---

## 5. Functional Flow

### Step 1: Infrastructure Provisioning & Configuration

- Terraform deploys the VPC, ECS Cluster, and IoT Core resources.
- A dedicated `init-s3-downloader` container runs first:
  - Downloads certificates and configuration files from a secured S3 bucket.
  - Writes them into a shared volume (e.g., `/mnt/config`, `/mnt/certs`) accessible by the application containers.

### Step 2: Simulation & Data Generation

- The IoT Simulator container (Python) starts up.
- It utilizes the certificates downloaded by the init container to authenticate with AWS IoT Core via **MQTTS (Port 8883)**.
- It publishes simulated telemetry data (e.g., temperature, vibration) to the topic:

```text
factory/simulator
```

### Step 3: Data Routing (The "Hot" & "Cold" Paths)

- **Cold Path (Storage):**  
  An IoT Topic Rule intercepts messages on `factory/simulator/#`. It routes the raw JSON data directly to an S3 Bucket for archival and historical analysis.

- **Hot Path (Monitoring):**  
  The simulator exposes metrics on port `9100`. The Prometheus container (running in the same task) scrapes these metrics every 15 seconds.

### Step 4: Visualization & Alerting

- Grafana connects to Prometheus (`localhost:9090`) as its data source.
- Users access the Grafana Dashboard via the Application Load Balancer URL.
- If metrics exceed defined thresholds, Grafana sends email alerts using credentials fetched securely from AWS Secrets Manager.

---

## 6. Deployment Guide

### Prerequisites

- **Terraform** (v1.9.5 or later)
- **AWS CLI** (v2.x) – configured via `aws configure` (Region: `us-east-1`)
- **Docker Desktop** – running (required for building the simulator image)
- **Git** – for version control
- Appropriate AWS permissions to manage IAM, ECS, IoT, S3, ALB, Secrets Manager, and DynamoDB.

---

### Step 1 — Bootstrap Backend

Initialize the local state to provision the S3 backend bucket and DynamoDB lock table first.

```bash
cd envs/dev
terraform apply
```

Or, for local testing with explicit variable file:

```bash
terraform apply -var-file=terraform.tfvars
```

**Action:** Review the plan and type `yes`.  
**Output:** Note the `ecr_repository_url` and `docker_push_command` from the output.

---

### Step 2 — Enable Backend

Once the backend infrastructure exists, uncomment the `backend.tf` configuration (if needed) and migrate the state to the remote backend.

```bash
# After ensuring backend.tf is active:
terraform init
```

---

### Step 3 — Deploy Full Stack

Provision the remaining infrastructure (VPC, ECS, IoT Core, etc.):

```bash
terraform apply
```

---

### Step 4 — Build & Push Simulator Image

The ECS tasks need the Docker image in ECR to start successfully.

```bash
# Login to ECR
aws ecr get-login-password --region <region> \
  | docker login --username AWS --password-stdin <ecr_repository_url>

# Build the image
docker build -t iot-simulator ../../resources/app

# Tag and Push
docker tag iot-simulator:latest <ecr_repository_url>:latest
docker push <ecr_repository_url>:latest
```

---

### Step 5 — Finalize: Force a New Deployment to Pull the Image

If you update the application code but keep the image tag as `latest`, Terraform will not detect a change because the Task Definition remains identical. To force ECS to pull the newly pushed image and restart the containers without changing infrastructure, run:

```bash
aws ecs update-service \
  --cluster <cluster_name> \
  --service <service_name> \
  --force-new-deployment
```

**Example:**

```bash
aws ecs update-service \
  --cluster grp1-ce11-dev-iot-cluster \
  --service dev-iot-service \
  --force-new-deployment \
  --region us-east-1
```

---

### Step 6 — Access Dashboards

Once the deployment is complete and the image is pushed, access your monitoring stack via the Application Load Balancer DNS (output by Terraform).

- **Grafana:**

  ```text
  http://<ALB-DNS>/
  ```

  Default credentials:

  ```text
  admin / admin
  ```

- **Prometheus:**

  ```text
  http://<ALB-DNS>/prometheus/
  ```

---

## 7. Operational Guide

### 7.1. Accessing the Application

- **Grafana Dashboard:**  
  Accessible via the Load Balancer URL on Port 80. Default credentials are `admin / admin`.

- **Prometheus:**  
  Accessible via the `/prometheus/` path on the same URL.

- **IoT Data:**  
  Raw JSON files are stored in the S3 bucket:

  ```text
  <env>-iot-telemetry-storage
  ```

### 7.2. Scaling & Updates

- **Scaling:**  
  To increase load, update `simulator_count` in Terraform variables and apply Terraform.

- **Updating Code:**  
  Rebuild the Docker image and push it to ECR, then update the ECS service (force new deployment).

- **Rotating Certificates:**  
  Place new certificates in `resources/certs/`, run Terraform with `enable_cert_upload=true`, and restart the ECS service.

---

## 8. Security & Governance

This project adheres to strict security standards and cloud-native governance best practices to ensure data integrity and infrastructure safety.

### Least Privilege IAM Roles

- **Task Role:**  
  Grants specific permission to read only from the Config S3 bucket and write logs to CloudWatch.

- **IoT Rule Role:**  
  Grants specific permission to `PutObject` only to the Telemetry S3 bucket.

### Network Isolation

- Security Groups act as a firewall.
- The ECS task accepts traffic only from the Load Balancer on:
  - Port 3000 (Grafana)
  - Port 9090 (Prometheus, via ALB path-based routing)

### Secrets Management

- Sensitive credentials, such as SMTP passwords for Grafana alerting, are never stored in plain text.
- They are managed via AWS Secrets Manager and injected as environment variables at runtime.

### Data Protection

- **S3 Encryption:**  
  All S3 buckets (Telemetry and Config) are configured with server-side encryption.

- **Public Access Block:**  
  Public access is strictly blocked at the bucket level to prevent accidental data exposure.

### Infrastructure State Management

- Terraform state is stored remotely in S3 with DynamoDB locking enabled.
- This prevents race conditions and state corruption during concurrent deployments by multiple team members.

### Auditability

- Resources are provisioned with consistent tagging (e.g., `Environment`, `Owner`) to facilitate cost tracking and security auditing.

### Code Security

- **No Hardcoded Secrets:**  
  The codebase is free of sensitive keys or passwords, ensuring it is safe for version control systems like GitHub.

### IaC Best Practices

- The infrastructure is **Modular**, **Reusable**, and **Environment-aware**, allowing for consistent deployments across Development, Staging, and Production environments without code duplication.

---

## 9. Key Features Demonstrated

- **Self-Healing Infrastructure:**  
  If a container crashes, ECS Fargate automatically provisions a new one.

- **Decoupled Architecture:**  
  The simulator logic is separate from the visualization logic, connected only by standard protocols (HTTP/Prometheus).

- **Automated Lifecycle Management:**  
  ECR Lifecycle policies automatically clean up old Docker images to manage costs.

- **Persistent Configuration:**  
  By using an Init Container pattern, the application can update configurations (dashboards, datasources) by simply updating files in S3, without rebuilding the Docker image.

---

## 10. Security & Credentials Configuration

_(Only for Standalone Mode / Local Testing / Non-CI-CD Flow)_

> **Important Context:**  
> This configuration is intended only for standalone testing.  
> Credentials will be placed manually on your local file system.  
> All sensitive files mentioned below (certificates, private keys, and local scripts) are included in `.gitignore` to prevent accidental commits.

### A. IoT Certificates (Manual Placement)

You must manually copy the required X.509 certificate files into the local Terraform directory.

**Action:** Place the following three files into:

```text
terraform/resources/certs/
```

- `AmazonRootCA1.pem`
- `device-certificate.pem.crt`
- `private.pem.key`

These files are protected by `.gitignore`.

### B. SSH Key Pair (EC2 Access)

For standalone testing, generate a fresh SSH key pair locally to allow access to simulator instances (if EC2 is used in your variant).

**Action:** Run the helper script to create the key pair in your AWS account and save the private key locally.

```bash
cd terraform/resources/scripts/
chmod +x create_keypair.sh
./create_keypair.sh
```

**Output:**

- Creates `grp1-ec2-keypair` in AWS.
- Saves `grp1-ec2-keypair.pem` in the current directory.
- Protected by `.gitignore` (`*.pem` ignored).

### C. Application Secrets (Grafana SMTP)

The ECS tasks require SMTP credentials to send alerts. You must manually push them to AWS Secrets Manager using a local script.

**Steps:**

1. **Prepare the Script:**

```bash
cd terraform/resources/scripts/
cp ensure-grafana-smtp-secret_template.sh ensure-grafana-smtp-secret.sh
chmod +x ensure-grafana-smtp-secret.sh
```

`ensure-grafana-smtp-secret.sh` is explicitly ignored by `.gitignore`.

2. **Inject Credentials:**

Open `ensure-grafana-smtp-secret.sh` in your text editor. Replace the `SECRET_STRING` block with your real testing credentials:

```bash
# ensure-grafana-smtp-secret.sh

SECRET_STRING='{
  "SMTP_USER": "your-real-email@gmail.com",
  "SMTP_PASSWORD": "your-real-app-password",
  "SMTP_HOST": "smtp.gmail.com:587",
  "SMTP_FROM": "your-real-email@gmail.com",
  "SMTP_NAME": "IoT Factory Simulator (Standalone)"
}'
```

3. **Deploy Secret:**

```bash
./ensure-grafana-smtp-secret.sh
```

---

## 11. Troubleshooting Common Issues

### 11.1. 502 Bad Gateway

**Symptom:** ECS-backed service behind ALB returns 502.  
**Likely Cause:** ECS task is stopped or failing health checks.

**Resolution:**

- Check CloudWatch Logs for the ECS task (e.g., `/ecs/iot-simulator`).
- Confirm containers start correctly and health checks are properly configured.

---

### 11.2. Simulator Crashes

**Symptoms:**

- Container exits repeatedly.
- Errors show missing certificates or S3 access failures.

**Likely Causes:**

- Missing certificates in S3.
- Incorrect S3 object names or paths.
- ECS Task Role missing `s3:GetObject` permission.

**Resolution:**

- Verify S3 keys match expected names.
- Confirm Task Role’s S3 permissions.
- Re-run Terraform if bucket/object provisioning changed.

---

### 11.3. No Data in Grafana

**Symptoms:**

- Dashboards load but show no data.
- Prometheus targets may be down.

**Possible Causes:**

- Prometheus not scraping the simulator.
- Port or path misconfiguration.
- Init container failed to write proper Prometheus configuration.

**Resolution:**

- Check Prometheus targets at `/prometheus/targets`.
- Verify simulator metrics endpoint is up.
- Review init container logs for Prometheus config generation.
- Confirm ECS Security Groups allow internal communication.

---

### 11.4. ECS Task Stuck in PENDING

**Possible Causes:**

- IAM roles (execution / task role) missing permissions.
- No available IPs in subnets.
- Network configuration issues (subnets, routing).

**Resolution:**

- Check ECS events for the service.
- Validate IAM roles and policies.
- Ensure subnets are correctly configured and routable.

---

### 11.5. IoT Messages Not Appearing in S3

**Possible Causes:**

- IoT Topic Rule misconfigured.
- IAM role for the rule missing S3 `PutObject` permission.
- S3 bucket policy not allowing IoT service principal.

**Resolution:**

- Verify IoT Rule SQL (e.g., `SELECT * FROM 'factory/simulator/#'`).
- Confirm IoT Rule’s IAM role and attached policy.
- Check S3 bucket policy for `Principal: { Service: "iot.amazonaws.com" }`.
- Use IoT logging to CloudWatch for rule execution errors (if enabled).

---

### 11.6. Grafana Not Loading Dashboards

**Possible Causes:**

- `s3_config` module did not upload files.
- Init container failed to download or place files correctly.
- Grafana provisioning paths are incorrect.

**Resolution:**

- Confirm objects exist in the config S3 bucket.
- Check init container logs for download and file write steps.
- Validate Grafana’s config and provisioning folder paths inside the container.

---

## 12. Troubleshooting Log

The following critical issues were encountered and resolved during the implementation phase.

### Issue 1: DynamoDB State Locking Failure

**Symptom:**  
`terraform apply` failed immediately with `ResourceNotFoundException`.

**Error Message:**

> Error acquiring the state lock: Unable to retrieve item from DynamoDB table "grp1-ce11-dev-iot-locks": ... Requested resource not found.

**Root Cause:**  
The `backend.tf` configuration expected a table named `grp1-ce11-dev-iot-locks`, but the bootstrap script created a generic table named `terraform-locks`.

**Resolution:**  
Manually created the specific table required by the configuration:

```bash
aws dynamodb create-table \
  --table-name grp1-ce11-dev-iot-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

---

### Issue 2: Environment Rehydration (Missing Dependencies)

**Context:**  
The AWS lab environment was reset, deleting external dependencies (Secrets, Key Pairs) that Terraform does not manage directly.

**Symptom:**

- Potential `ResourceInitializationError` in ECS (due to missing secrets).
- EC2 creation failure (due to missing key pair) in earlier iterations.

**Resolution:**  
Established a **Rehydration Procedure** using helper scripts:

- Ran `./ensure-grafana-smtp-secret.sh` to restore the `grafana/smtp` secret.
- Ran `./create_keypair.sh` to restore the `grp1-ec2-keypair`.

---

### Issue 3: ALB Routing Conflict (Grafana vs. Prometheus)

**Symptom:**  
Accessing `http://<ALB_DNS>/prometheus` resulted in a Grafana 404 page instead of the Prometheus UI.

**Root Cause:**

- The ALB Listener Rules had conflicting priorities.
- The Grafana "catch-all" rule (`path_pattern = "/*"`) had a higher priority (lower number) than the Prometheus rule (`path_pattern = "/prometheus/*"`), shadowing it.

**Resolution:**

- Updated `modules/iot-simulator-ecs/main.tf` to:
  - Assign **Priority 90** to Prometheus.
  - Assign **Priority 100** to Grafana.
- Updated Prometheus container configuration to include:

  ```text
  --web.external-url=/prometheus/
  --web.route-prefix=/prometheus/
  ```

- Removed duplicate listener rules from the shared-alb module to prevent state conflicts.

---

## 13. Future Roadmap & Improvements

While the current deployment is fully functional and automated, the following enhancements are planned to further harden security, optimize costs, and improve scalability.

### 🔐 Security & Network Hardening

- **HTTPS/SSL Enforcement:** Secure the application by attaching an AWS Certificate Manager (ACM) certificate to the Application Load Balancer (ALB). This will enable encrypted traffic on port 443 and ensure a secure browsing experience.
- **Private Subnet Architecture:** Move ECS tasks and backend resources to private subnets with NAT Gateways. This isolates compute resources from direct internet access, significantly reducing the attack surface.
- **AWS WAF (Web Application Firewall):** Attach AWS WAF to the ALB to protect the application against common web exploits (SQL injection, XSS) and malicious bot traffic.
- **Environment-Specific IoT Certificates:** Implement distinct AWS IoT Certificates for `Dev` and `Prod` environments. This ensures complete cryptographic isolation, preventing a compromised development key from affecting production.
- **Secret Rotation:** Implement AWS Secrets Manager with automatic rotation policies for database credentials and Grafana SMTP passwords.

### 🏗️ Architecture & Scalability

- **ECS Autoscaling:** Configure Service Auto Scaling policies to automatically adjust the number of ECS tasks based on real-time CPU or Memory utilization, ensuring performance during traffic spikes.
- **Decoupling with SQS/SNS:** Introduce Amazon SQS (Simple Queue Service) between the AWS IoT Core rules and the backend processing. This will buffer traffic bursts and improve system resilience.
- **Strict IoT Topic Isolation:** Enforce strict topic prefixes (e.g., `iot/prod/...` vs `iot/dev/...`) via IoT Policies to preventing accidental data crossover between simulator testing and production dashboards.
- **Multi-AZ Database:** Upgrade the backend state storage to a Multi-AZ DynamoDB or RDS configuration to ensure high availability and failover capabilities for Production.

### 🤖 DevOps & Observability

- **Alerting Enhancements:** Integrate Prometheus Alertmanager to route critical alerts to email, Slack, or SNS topics, ensuring faster incident response times.
- **Terraform Drift Detection:** Implement a scheduled GitHub Action to run `terraform plan` periodically. This alerts the team to manual changes (Configuration Drift) made in the AWS Console, preventing "Zombie Resource" conflicts.
- **Automated Rollbacks:** Enhance the ECS deployment strategy to automatically roll back to the previous stable image if a new task fails health checks within the first 5 minutes.
- **S3 Lifecycle Policies:** Configure lifecycle rules for telemetry and state buckets to automatically transition old data to Amazon S3 Glacier or expire it, optimizing long-term storage costs.
- **Cost-Optimized Logging:** Configure distinct CloudWatch Log retention policies via Terraform variables (e.g., 3 days for Dev to save costs, 30 days for Prod for auditing).

### 🧪 Testing & Validation

- **Load Testing:** Integrate testing tools like k6 or JMeter into the pipeline to simulate high-throughput IoT telemetry traffic before promoting code to Production.

---
