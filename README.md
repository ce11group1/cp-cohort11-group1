Here is the comprehensive `README.md` file, faithfully converted from the provided documentation. It includes all technical details, the standalone security configuration, and the troubleshooting logs as requested.

---

# Capstone Project: IoT Factory Simulator

## 1. Executive Summary

This project is a cloud-native **IoT Factory Simulator** designed to generate, transmit, store, and visualize real-time telemetry data. The infrastructure allows for scalable device simulation using **AWS IoT Core** for connectivity and **ECS Fargate** for compute, while leveraging **Prometheus** and **Grafana** for observability. The entire stack is provisioned using **Terraform** (Infrastructure as Code) to ensure reproducibility and modularity.

## 2. System Architecture

The architecture follows a microservices approach deployed on AWS. The system is divided into three main logical layers: **Connectivity (IoT)**, **Compute (ECS)**, and **Storage/Observability**.

### Core Components:

* 
**VPC Network:** A custom VPC with public subnets spanning multiple Availability Zones for high availability.


* 
**IoT Core:** Managed MQTT broker acting as the entry point for device data.


* 
**ECS Fargate Cluster:** Serverless container orchestration running the simulator application and monitoring stack side-by-side.


* 
**Application Load Balancer (ALB):** Provides a secure HTTP entry point for accessing the Grafana dashboard.


* 
**S3 Storage:** Used for long-term data archiving (Cold Storage) and configuration management.



## 3. Technology Stack & Resources Used

| Resource / Tool | Technology | Reason for Selection (Justification) |
| --- | --- | --- |
| **IaC** | Terraform | Modular infrastructure management: state locking via DynamoDB ensures team collaboration safety.

 |
| **Compute** | AWS ECS (Fargate) | Serverless container execution removes the need to manage EC2 instances/OS patching.

 |
| **Connectivity** | AWS IoT Core | Fully managed MQTT broker that handles mutual TLS authentication and scales automatically.

 |
| **Storage** | AWS S3 | Cost-effective storage for telemetry logs (via IoT Rules) and dynamic configuration files.

 |
| **Visualization** | Grafana | Industry-standard visualization tool; deployed as a container to provide custom dashboards.

 |
| **Monitoring** | Prometheus | Scrapes metrics from the simulator application locally within the ECS task, ensuring low latency monitoring.

 |
| **Networking** | AWS ALB | Distributes incoming traffic to the Grafana container and provides a static DNS endpoint.

 |
| **Security** | Secrets Manager | Securely manages sensitive credentials (SMTP passwords) without hardcoding them in Terraform.

 |

## 4. Technical Deep Dive

### 4.1. ECS Fargate Task Architecture

The application runs as a single ECS Task containing four tightly coupled containers using the "Sidecar" pattern.

1. 
**Init Container (`init-s3-downloader`):** Runs pre-boot to download certificates and configurations (Grafana dashboards, Prometheus YAMLs) from S3 to a shared volume. It handles dynamic configuration injections at runtime.


2. 
**App Container (`iot-simulator`):** The core Python script that connects to AWS IoT Core via MQTT (Port 8883) using X.509 certificates.


3. 
**Prometheus Container:** Scrapes metrics from `localhost:9100` and stores them in memory.


4. 
**Grafana Container:** Reads provisioned dashboards from the shared volume and queries `localhost:9090` (Prometheus).



## 5. Functional Flow

**Step 1: Infrastructure Provisioning & Configuration**
Terraform deploys the VPC, ECS Cluster, and IoT Core resources. An `init-s3-downloader` container runs first, downloading certificates and configuration files from a secured S3 bucket to a shared volume (`/mnt/config`).

**Step 2: Simulation & Data Generation**
The **IoT Simulator** container starts up and utilizes the downloaded certificates to authenticate with **AWS IoT Core** via **MQTTS (Port 8883)**. It publishes simulated telemetry data to the topic `factory/simulator`.

**Step 3: Data Routing (The "Hot" & "Cold" Paths)**

* 
**Cold Path (Storage):** An **IoT Topic Rule** intercepts messages on `factory/simulator/#` and routes raw JSON data directly to an **S3 Bucket** for archival.


* 
**Hot Path (Monitoring):** The simulator exposes metrics on port 9100, which the **Prometheus** container scrapes every 15 seconds.



**Step 4: Visualization & Alerting**


**Grafana** connects to Prometheus (`localhost:9090`) as its data source. Users access the dashboard via the **Application Load Balancer** URL. If metrics exceed defined thresholds, Grafana sends email alerts using credentials fetched securely from **AWS Secrets Manager**.

## 6. Deployment Guide

### Prerequisites

* AWS CLI (v2.x) configured with `aws configure` (Region: `us-east-1`).


* Terraform installed (v1.9.5 or later).


* Docker Desktop running (required for building the simulator image).


* Git for version control.



### Step 1: Bootstrap Backend

Initialize the local state to provision the S3 backend bucket and DynamoDB lock table first.

```bash
# For CI/CD - Automated testing:
cd envs/dev
terraform apply

```
OR

```bash
# For local testing execute:
cd envs/dev
terraform apply -var-file=terraform.tfvars

```

* 
**Action:** Review the plan and type `yes`.


* 
**Output:** Note the `ecr_repository_url` and `docker_push_command` from the output.



### Step 2: Enable Backend

Once the backend infrastructure exists, uncomment the `backend.tf` configuration and migrate the state to the remote backend.

```bash
# Uncomment backend.tf configuration first, then run:
terraform init

```

### Step 3: Deploy Full Stack

Provision the remaining infrastructure (VPC, ECS, IoT Core, etc.).

```bash
terraform apply

```

### Step 4: Build & Push Simulator Image

The ECS tasks need the Docker image in ECR to start successfully.

```bash
# Login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <ecr_repository_url>

# Build the image
docker build -t iot-simulator ../../resources/app

# Tag and Push
docker tag iot-simulator:latest <ecr_repository_url>:latest
docker push <ecr_repository_url>:latest

```

### Step 5: Finalize (Force Deployment)

If you update the application code but keep the image tag as `latest`, Terraform will not detect a change. Force ECS to pull the newly pushed image.

```bash
aws ecs update-service \
  --cluster grp1-ce11-dev-iot-cluster \
  --service dev-iot-service \
  --force-new-deployment \
  --region us-east-1

```

### Step 6: Access Dashboards

Once deployed, access your monitoring stack via the ALB DNS.

* 
**Grafana:** `http://<ALB-DNS>/` (Default: admin / admin).


* 
**Prometheus:** `http://<ALB-DNS>/prometheus/`.



## 7. Operational Guide

### 5.1. Accessing the Application

* 
**Grafana Dashboard:** Accessible via the Load Balancer URL on **Port 80**.


* 
**Prometheus:** Accessible via the `/prometheus/` path on the same URL.


* 
**IoT Data:** Raw JSON files are stored in the `<env>-iot-telemetry-storage` S3 bucket.



### 5.2. Scaling & Updates

* 
**Scaling:** Update `simulator_count` in `variables.tf` and apply Terraform.


* 
**Updating Code:** Rebuild Docker image, push to ECR, and update ECS service.


* 
**Rotating Certificates:** Place new certificates in `resources/certs/`, run Terraform with `enable_cert_upload=true`, and restart ECS.



## 8. Security & Governance

* **Least Privilege IAM Roles:**
* 
**Task Role:** Reads from Config S3, writes logs to CloudWatch.


* 
**IoT Rule Role:** Permissions limited to `PutObject` on the Telemetry S3 bucket.




* 
**Network Isolation:** Security Groups restrict ECS traffic to only accept connections from the ALB on ports 3000 and 9090.


* 
**Secrets Management:** Sensitive credentials (SMTP) are managed via **AWS Secrets Manager** and injected as environment variables.


* 
**Data Protection:** S3 buckets use server-side encryption and block public access.


* 
**State Management:** Terraform state is stored remotely in S3 with **DynamoDB locking** to prevent race conditions.



## 9. Key Features Demonstrated

* 
**Self-Healing Infrastructure:** ECS Fargate automatically replaces crashed containers.


* 
**Decoupled Architecture:** Simulator and visualization logic are connected only by standard protocols.


* 
**Automated Lifecycle Management:** ECR Lifecycle policies clean up old images.


* 
**Persistent Configuration:** Init Container pattern allows configuration updates without rebuilding Docker images.



## 10. Security & Credentials Configuration (Only for Standalone Mode)

> **⚠️ Important Context:** This configuration is intended **only for standalone testing**. Credentials will be placed manually on your local file system .
> 
> 

**Security Note:** All sensitive files mentioned below (certificates, private keys, and local scripts) are already included in `.gitignore` to prevent accidental commits.

### A. IoT Certificates (Manual Placement)

You must manually copy the required X.509 certificate files into the local Terraform directory.

**Action:** Place the following files into `terraform/resources/certs/`:

* `AmazonRootCA1.pem`
* `device-certificate.pem.crt`
* `private.pem.key`


*(Protected by `.gitignore`: All files within `terraform/resources/certs/` are ignored)*.



### B. SSH Key Pair (EC2 Access)

For standalone testing, generate a fresh SSH key pair locally to allow access to the simulator instances.

**Action:** Run the helper script:

```bash
cd terraform/resources/scripts/
chmod +x create_keypair.sh
./create_keypair.sh

```

* 
**Output:** Creates `grp1-ec2-keypair` in AWS.


* 
**Local File:** Saves `grp1-ec2-keypair.pem` in the current directory (Ignored by git).



### C. Application Secrets (Grafana SMTP)

The ECS tasks require SMTP credentials to send alerts. Manually push them to AWS Secrets Manager using a local script.

**1. Prepare the Script:**
Duplicate the template to create your active script.

```bash
cd terraform/resources/scripts/
cp ensure-grafana-smtp-secret_template.sh ensure-grafana-smtp-secret.sh
chmod +x ensure-grafana-smtp-secret.sh

```

*(Protected by `.gitignore`)*.

**2. Inject Credentials:**
Open `ensure-grafana-smtp-secret.sh` and replace the `SECRET_STRING` block with your real credentials:

```bash
SECRET_STRING='{
  "SMTP_USER": "your-real-email@gmail.com",
  "SMTP_PASSWORD": "your-real-app-password",
  "SMTP_HOST": "smtp.gmail.com:587",
  "SMTP_FROM": "your-real-email@gmail.com",
  "SMTP_NAME": "IoT Factory Simulator (Standalone)"
}'

```

**3. Deploy Secret:**

```bash
./ensure-grafana-smtp-secret.sh

```

## 11. Troubleshooting Common Issues

* **502 Bad Gateway:** ECS task is stopped. Check CloudWatch Logs (`/ecs/iot-simulator`).


* 
**Simulator Crashes:** Verify IAM Role has `s3:GetObject` permissions and filenames match.


* 
**No Data in Grafana:** Check if the simulator is UP via `/prometheus/targets` and ensure Security Groups allow port 9100.


* 
**ECS Task Pending:** Check for missing IAM permissions, subnets not being public, or ALB security group issues .


* 
**IoT Messages not in S3:** Check IoT Rule SQL, IAM role, and bucket policy .



## 12. Troubleshooting Log

The following critical issues were encountered and resolved during implementation.

**Issue 1: DynamoDB State Locking Failure**

* 
**Symptom:** `terraform apply` failed with `ResourceNotFoundException`.


* 
**Root Cause:** `backend.tf` expected `grp1-ce11-dev-iot-locks`, but bootstrap created `terraform-locks`.


* 
**Resolution:** Manually created the specific table using `aws dynamodb create-table` .



**Issue 2: Environment Rehydration (Missing Dependencies)**

* 
**Context:** AWS lab environment reset deleted external dependencies (Secrets, Key Pairs).


* 
**Resolution:** Established a "Rehydration Procedure" using helper scripts (`./ensure-grafana-smtp-secret.sh` and `./create_keypair.sh`) .



**Issue 3: ALB Routing Conflict (Grafana vs. Prometheus)**

* 
**Symptom:** Accessing `/prometheus` resulted in a Grafana 404 page.


* 
**Root Cause:** Grafana "catch-all" rule (`/*`) had higher priority than Prometheus rule (`/prometheus/*`).


* 
**Resolution:** Assigned Priority 90 to Prometheus and Priority 100 to Grafana in `main.tf`.



## 13. Future Enhancements (Roadmap)

* 
**Private Subnets:** Move ECS tasks to private subnets with NAT Gateways for enhanced security.


* 
**HTTPS/SSL:** Attach an ACM Certificate to the ALB (Port 443) for secure access.


* 
**CI/CD Pipeline:** Fully automate `terraform apply` and `docker push` via GitHub Actions.


* 
**Autoscaling:** Enable autoscaling for ECS.
