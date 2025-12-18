**Reconstructing the document**

Alright, I need to carefully redo the conversion, including everything from the docx file. The user mentioned something is missing, so I'll make sure to include everything. I’ll provide the full README without any added commentary. I’ll systematically reconstruct it from their text, making sure to preserve all sections, 1–13, and subpoints, using markdown. No omissions. I'll keep the headings exactly the same, matching the titles.
```markdown
# IoT Factory Simulator – Capstone Project

## 1. Executive Summary

This project is a cloud-native **IoT Factory Simulator** designed to generate, transmit, store, and visualize real-time telemetry data. The infrastructure allows for scalable device simulation using **AWS IoT Core** for connectivity and **ECS Fargate** for compute, while leveraging **Prometheus** and **Grafana** for observability. The entire stack is provisioned using **Terraform** (Infrastructure as Code) to ensure reproducibility and modularity.

---

## 2. System Architecture

The architecture follows a microservices approach deployed on AWS. The system is divided into three main logical layers:

- **Connectivity (IoT)**  
- **Compute (ECS)**  
- **Storage / Observability (S3, Prometheus, Grafana)**  

### High-Level Architecture Diagram

> (As described in the document – this can be represented as an image or Mermaid diagram in the repo.)

**Core Components:**

- **VPC Network:**  
  A custom VPC with public subnets spanning multiple Availability Zones for high availability.

- **IoT Core:**  
  Managed MQTT broker acting as the entry point for device data.

- **ECS Fargate Cluster:**  
  Serverless container orchestration running the simulator application and monitoring stack side-by-side.

- **Application Load Balancer (ALB):**  
  Provides a secure HTTP entry point for accessing the Grafana dashboard.

- **S3 Storage:**  
  Used for long-term data archiving (Cold Storage) and configuration management.

---

## 3. Technology Stack & Resources Used

| Resource / Tool | Technology          | Reason for Selection (Justification)                                                                 |
|-----------------|---------------------|------------------------------------------------------------------------------------------------------|
| IaC             | Terraform           | Modular infrastructure management; state locking via DynamoDB ensures safe team collaboration.       |
| Compute         | AWS ECS (Fargate)   | Serverless container execution removes EC2/OS management; supports sidecar containers (Prometheus). |
| Connectivity    | AWS IoT Core        | Fully managed MQTT broker with mutual TLS; scales automatically to millions of messages.            |
| Storage         | AWS S3              | Cost-effective storage for telemetry logs and dynamic configuration files for containers.           |
| Visualization   | Grafana             | Industry-standard visualization tool; containerized for custom IoT dashboards.                      |
| Monitoring      | Prometheus          | Scrapes metrics locally within the ECS task, ensuring low-latency monitoring.                       |
| Networking      | AWS ALB             | Distributes incoming traffic to Grafana / Prometheus and provides a static DNS endpoint.            |
| Security        | AWS Secrets Manager | Securely manages sensitive credentials (SMTP passwords for Grafana alerts) without hardcoding.      |

---

## 4. Technical Deep Dive

### 4.1. ECS Fargate Task Architecture

The application runs as a **single ECS Task** containing four tightly coupled containers using the *Sidecar* pattern.

1. **Init Container (`init-s3-downloader`):**  
   - Runs before other containers.  
   - Downloads certificates and configurations (Grafana dashboards, Prometheus YAMLs) from S3 to a shared volume.  
   - Handles dynamic configuration injection at runtime.

2. **App Container (`iot-simulator`):**  
   - Core Python script that connects to AWS IoT Core via MQTT (port 8883) using X.509 certificates.  
   - Publishes simulated telemetry data.

3. **Prometheus Container:**  
   - Scrapes metrics from `localhost:9100`.  
   - Stores metrics in memory.

4. **Grafana Container:**  
   - Reads provisioned dashboards from the shared volume.  
   - Queries Prometheus on `localhost:9090` as its data source.

---

## 5. Functional Flow

### Step 1: Infrastructure Provisioning & Configuration

- Terraform deploys the VPC, ECS Cluster, IoT Core resources, S3 buckets, and ALB.  
- A dedicated **init-s3-downloader** container runs first.  
  - It downloads certificates and configuration files from a secured S3 bucket to a shared volume (`/mnt/config`, `/mnt/certs`) accessible by the application containers.

### Step 2: Simulation & Data Generation

- The IoT Simulator container (Python) starts up.  
- It uses the downloaded certificates to authenticate with AWS IoT Core via **MQTTS (port 8883)**.  
- It publishes simulated telemetry data (e.g., temperature, vibration) to the topic:

```text
factory/simulator
```

### Step 3: Data Routing (The "Hot" & "Cold" Paths)

- **Cold Path (Storage):**  
  - An AWS IoT Topic Rule intercepts messages on `factory/simulator/#`.  
  - Routes raw JSON data directly to an S3 bucket for archival and historical analysis.

- **Hot Path (Monitoring):**  
  - The simulator exposes metrics on port `9100`.  
  - The Prometheus container (running in the same task) scrapes these metrics every 15 seconds.

### Step 4: Visualization & Alerting

- Grafana connects to Prometheus (`localhost:9090`) as its data source.  
- Users access the Grafana dashboard via the Application Load Balancer URL.  
- If metrics exceed defined thresholds, Grafana sends email alerts using credentials fetched securely from **AWS Secrets Manager**.

---

## 6. Deployment Guide

### Prerequisites

- **Terraform** (v1.9.5 or later)  
- **AWS CLI** (v2.x) – configured with `aws configure` (Region: `us-east-1`)  
- **Docker Desktop** – running (for building the simulator image)  
- **Git** – for version control  
- AWS account with permissions to manage IAM, ECS, IoT, S3, ALB, Secrets Manager, DynamoDB.

---

### Step 1 — Bootstrap Backend

Initialize the local state to provision the **S3 backend bucket** and **DynamoDB lock table** first.

```bash
cd envs/dev
terraform apply
```

Or for explicit var-file usage:

```bash
terraform apply -var-file=terraform.tfvars
```

- **Action:** Review the plan and type `yes`.  
- **Output:** Note the `ecr_repository_url` and `docker_push_command` from the Terraform output.

---

### Step 2 — Enable Backend

Once the backend infrastructure exists, uncomment the `backend.tf` configuration (if commented out) and migrate the state to the remote backend:

```bash
terraform init
```

---

### Step 3 — Deploy Full Stack

Provision the remaining infrastructure (VPC, ECS, IoT Core, ALB, S3, IAM, etc.):

```bash
terraform apply
```

---

### Step 4 — Build & Push Simulator Image

The ECS tasks require the Docker image to be present in ECR.

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

If you update the application code but keep the image tag as `latest`, Terraform will not detect a change because the Task Definition remains identical.

To force ECS to pull the newly pushed image and restart the containers *without* changing infrastructure, run:

```bash
aws ecs update-service \
  --cluster <cluster_name> \
  --service <service_name> \
  --force-new-deployment \
  --region us-east-1
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

Once deployment is complete and the image is pushed:

- **Grafana**

  ```text
  http://<ALB-DNS>/
  ```

  Default credentials:

  ```text
  admin / admin
  ```

- **Prometheus**

  ```text
  http://<ALB-DNS>/prometheus/
  ```

---

## 7. Operational Guide

### 7.1. Accessing the Application

- **Grafana Dashboard:**  
  Accessible via the Load Balancer URL on port 80.  
  Default credentials: `admin / admin`.

- **Prometheus:**  
  Accessible via the `/prometheus/` path on the same URL.

- **IoT Data:**  
  Raw JSON files are stored in the S3 bucket:

  ```text
  <env>-iot-telemetry-storage
  ```

### 7.2. Scaling & Updates

- **Scaling:**  
  Increase workload by updating `simulator_count` in Terraform variables and re-running `terraform apply`.

- **Updating Code:**  
  Rebuild the Docker image, push it to ECR, then use `aws ecs update-service --force-new-deployment`.

- **Rotating Certificates:**  
  Place new certificates into `resources/certs/`, ensure `enable_cert_upload=true`, and re-run Terraform plus ECS restart.

---

## 8. Security & Governance

This project follows strict security and governance best practices.

### Least Privilege IAM Roles

- **Task Role:**  
  Grants only the required permissions (e.g., `s3:GetObject` from config/cert buckets, `logs:PutLogEvents`).

- **IoT Rule Role:**  
  Grants only `s3:PutObject` (and optionally `PutObjectAcl`) to the telemetry S3 bucket.

### Network Isolation

- Security Groups act as firewalls.  
- ECS task accepts inbound traffic only from the ALB on:
  - Port **3000** (Grafana)  
  - Port **9090** (Prometheus via ALB path routing)  

### Secrets Management

- Sensitive credentials (e.g., SMTP passwords for Grafana alerting) are stored in **AWS Secrets Manager**.  
- No secrets are hardcoded in Terraform or application code.

### Data Protection

- **S3 Encryption:** All S3 buckets (Telemetry, Config, Certs) use server-side encryption.  
- **Public Access Block:** Public access is blocked at the bucket level to prevent accidental exposure.

### Infrastructure State Management

- Terraform state stored in **S3**.  
- **DynamoDB locking** is enabled to prevent concurrent state modification.

### Auditability

- Consistent tagging: `Environment`, `Owner`, `Project`, etc.  
- Supports cost tracking, security analysis, and compliance audits.

### Code Security

- No hardcoded secrets.  
- Secrets and keys are `.gitignore`d and never committed to version control.

### IaC Best Practices

- Modular, reusable, environment-aware Terraform modules.  
- Supports Dev / Staging / Prod with minimal duplication.

---

## 9. Key Features Demonstrated

- **Self-Healing Infrastructure:**  
  ECS Fargate automatically replaces failed containers.

- **Decoupled Architecture:**  
  Simulation logic separated from visualization and storage; communication via standard protocols (MQTT, HTTP, Prometheus).

- **Automated Lifecycle Management:**  
  ECR lifecycle policies clean up old images to control cost.

- **Persistent Configuration via Init Container:**  
  Grafana dashboards, data sources, and Prometheus configs come from S3, enabling updates without rebuilding Docker images.

---

## 10. Security & Credentials Configuration  
*(Only for Standalone Mode / Local Testing / Non-CI-CD Flow)*

> **Important:**  
> This configuration is intended only for **standalone testing**.  
> Sensitive files are ignored by `.gitignore`.

### A. IoT Certificates (Manual Placement)

Manually copy required X.509 certificates into the local Terraform directory:

Place the following files into:

```text
terraform/resources/certs/
```

- `AmazonRootCA1.pem`  
- `device-certificate.pem.crt`  
- `private.pem.key`

These paths are protected by `.gitignore`.

### B. SSH Key Pair (EC2 Access – if used)

For standalone testing, generate an SSH key pair locally (where relevant):

```bash
cd terraform/resources/scripts/
chmod +x create_keypair.sh
./create_keypair.sh
```

- Creates `grp1-ec2-keypair` in AWS.  
- Saves `grp1-ec2-keypair.pem` locally.  
- `*.pem` is ignored by `.gitignore`.

### C. Application Secrets (Grafana SMTP)

The ECS tasks require SMTP credentials for alerting.

1. Prepare the script:

```bash
cd terraform/resources/scripts/
cp ensure-grafana-smtp-secret_template.sh ensure-grafana-smtp-secret.sh
chmod +x ensure-grafana-smtp-secret.sh
```

`ensure-grafana-smtp-secret.sh` is ignored by `.gitignore`.

2. Edit the script and set:

```bash
SECRET_STRING='{
  "SMTP_USER": "your-real-email@gmail.com",
  "SMTP_PASSWORD": "your-real-app-password",
  "SMTP_HOST": "smtp.gmail.com:587",
  "SMTP_FROM": "your-real-email@gmail.com",
  "SMTP_NAME": "IoT Factory Simulator (Standalone)"
}'
```

3. Deploy the secret:

```bash
./ensure-grafana-smtp-secret.sh
```

---

## 11. Troubleshooting Common Issues

### 11.1 502 Bad Gateway

**Symptom:** ALB shows 502.  
**Cause:** ECS task stopped or unhealthy target.  
**Action:**  
- Check CloudWatch Logs: `/ecs/iot-simulator`.  
- Ensure the containers start successfully and health checks pass.

### 11.2 Simulator Crashes

**Causes:**

- Missing certificates in S3 or incorrect filenames.  
- IAM role missing `s3:GetObject` permissions.

**Action:**

- Verify S3 object keys match expected names.  
- Check IAM policies for the ECS task role.

### 11.3 No Data in Grafana

**Causes:**

- Prometheus not scraping the simulator.  
- Incorrect Prometheus config in the init container.

**Action:**

- Check Prometheus targets at `/prometheus/targets`.  
- Verify security groups allow access on the internal ports.  
- Review init container logs for config generation.

### 11.4 ECS Task Stuck in PENDING

**Possible Causes:**

- Missing IAM: ECS execution role or task role policies.  
- Subnets not public / no route to internet when needed.  
- ALB security group cannot reach ECS security group.

### 11.5 IoT Messages Not Appearing in S3

**Action:**

- Verify IoT Rule SQL: `SELECT * FROM 'factory/simulator/#'` (or configured topic).  
- Check IAM role attached to IoT Rule (S3 `PutObject`).  
- Confirm bucket policy allows IoT service principal.  
- Use IoT logging (CloudWatch) to inspect errors.

### 11.6 Grafana Not Loading Dashboards

**Action:**

- Confirm `s3_config` uploaded files to the config bucket.  
- Verify init container logs show successful downloads.  
- Validate paths under `/etc/grafana` in the Grafana container.

---

## 12. Troubleshooting Log (Detailed)

### Issue 1: DynamoDB State Locking Failure

**Symptom:**  
`terraform apply` failed with `ResourceNotFoundException`:

> Error acquiring the state lock: Unable to retrieve item from DynamoDB table "grp1-ce11-dev-iot-locks": Requested resource not found.

**Root Cause:**  
`backend.tf` expected table `grp1-ce11-dev-iot-locks` but the bootstrap script created a different table name.

**Resolution:**

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
Lab environment reset removed external dependencies that Terraform does not manage (Secrets, Key Pairs).

**Symptoms:**  
- ECS `ResourceInitializationError` due to missing secret.  
- EC2 key pair missing (if used in an earlier iteration).

**Resolution:**

- Ran `./ensure-grafana-smtp-secret.sh` to restore `grafana/smtp` secret.  
- Ran `./create_keypair.sh` to restore `grp1-ec2-keypair`.

---

### Issue 3: ALB Routing Conflict (Grafana vs. Prometheus)

**Symptom:**  
Accessing `http://<ALB_DNS>/prometheus` showed a Grafana 404 instead of Prometheus UI.

**Root Cause:**  

- ALB Listener Rules:  
  - Grafana rule used catch‑all path `/*` with a **higher priority** (lower number) than the Prometheus rule `/prometheus/*`.  
  - This shadowed the Prometheus rule.

**Resolution:**

- Updated `modules/iot-simulator-ecs/main.tf`:
  - Prometheus rule → priority `90`  
  - Grafana rule → priority `100`
- Configured Prometheus container with:

  ```text
  --web.external-url=/prometheus/
  --web.route-prefix=/prometheus/
  ```

- Removed duplicate listener rules from the `shared-alb` module to prevent state conflicts.

---

## 13. Future Enhancements (Roadmap)

- **Private Subnets:**  
  Move ECS tasks into private subnets with NAT Gateways for improved security (currently using public subnets for cost optimization and simplicity).

- **HTTPS / SSL:**  
  Attach an ACM certificate to the ALB to enable HTTPS (port 443).  
  - Request a certificate in ACM.  
  - Add an HTTPS listener on the ALB.  
  - Redirect HTTP → HTTPS.

- **CI/CD Pipeline:**  
  Automate:
  - `terraform apply`  
  - Docker build & push  
  using GitHub Actions or AWS CodePipeline.

- **Autoscaling for ECS:**  
  Scale tasks based on CPU, memory, or custom CloudWatch metrics.

- **Alerting Improvements:**  
  - Integrate Prometheus Alertmanager.  
  - SNS / Email / Slack alert channels.

- **S3 Lifecycle Policies:**  
  Configure lifecycle rules for telemetry S3 buckets to transition or expire old data.

---
```
