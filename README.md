# Capstone Project: Smart IoT Factory Simulator

## Appendix A: Implementation, Operations & Troubleshooting Guide

### **1. Prerequisites & Environment Setup**

Before deploying the infrastructure, the following tools and configurations must be established in the local development environment.

#### **1.1. Required Tools**

Ensure the following are installed and configured:

  * **Terraform** (v1.9.5 or later)
  * **AWS CLI** (v2.x) – Configured with `aws configure` (Region: `us-east-1`)
  * **Docker Desktop** – Running (required for building the simulator image)
  * **Git** – For version control

#### **1.2. Backend Infrastructure Initialization**

To enable Terraform to store state securely and prevent concurrent modifications, the backend resources must be bootstrapped.

1.  Navigate to the scripts directory: `terraform/resources/scripts/`
2.  Execute the setup script:
    ```bash
    ./setup_backend.sh
    ```
      * *Creates S3 Bucket:* `grp1-ce11-iot-factory-state-bucket`
      * *Creates DynamoDB Table:* `terraform-locks`

#### **1.3. Security & Credentials Configuration**

This project requires specific secure credentials to be present in the AWS account before the infrastructure can be provisioned.

**A. IoT Certificates**
Ensure the following X.509 certificate files are placed in `terraform/resources/certs/`:

  * `AmazonRootCA1.pem`
  * `device-certificate.pem.crt`
  * `private.pem.key`

**B. SSH Key Pair (for EC2 Access)**
Run the helper script to generate the key pair required for the EC2 simulator instances.

```bash
cd terraform/resources/scripts/
chmod +x create_keypair.sh
./create_keypair.sh
```

  * *Outcome:* Creates `grp1-ec2-keypair` in AWS and saves `grp1-ec2-keypair.pem` locally.

**C. Application Secrets (Grafana SMTP)**
The ECS Task Definition requires SMTP credentials to send alerts. These are stored in AWS Secrets Manager.

  * *Note:* The repository contains a template file that must be updated with valid credentials.

<!-- end list -->

1.  **Rename the template:**
    ```bash
    cd terraform/resources/scripts/
    cp ensure-grafana-smtp-secret_template.sh ensure-grafana-smtp-secret.sh
    chmod +x ensure-grafana-smtp-secret.sh
    ```
2.  **Edit the script:** Open `ensure-grafana-smtp-secret.sh` and populate the `SECRET_STRING` variable with your actual credentials:
    ```bash
    SECRET_STRING='{
      "SMTP_USER": "your-email@gmail.com",
      "SMTP_PASSWORD": "your-app-password",
      "SMTP_HOST": "smtp.gmail.com:587",
      "SMTP_FROM": "your-email@gmail.com",
      "SMTP_NAME": "IoT Factory Simulator"
    }'
    ```
3.  **Run the script:**
    ```bash
    ./ensure-grafana-smtp-secret.sh
    ```

-----

### **2. Deployment Steps**

#### **2.1. Infrastructure Provisioning (Terraform)**

1.  Navigate to the development environment:
    ```bash
    cd terraform/envs/dev
    ```
2.  Initialize Terraform:
    ```bash
    terraform init
    ```
3.  Apply the configuration:
    ```bash
    terraform apply -var-file=terraform.tfvars
    ```
      * **Action:** Review the plan and type `yes`.
      * **Output:** Note the `ecr_repository_url` and `docker_push_command` from the output.

#### **2.2. Application Build & Release**

Terraform creates the ECR registry infrastructure, but the application lifecycle (building and updating the code) is handled externally.

1.  **Authenticate Docker to ECR:**
    *(Run this command using the AWS CLI credentials configured earlier)*

    ```bash
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <YOUR_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
    ```

2.  **Build the Image:**
    *(Run from project root context)*

    ```bash
    docker build -t iot-simulator -f terraform/resources/app/Dockerfile terraform/resources/
    ```

3.  **Push to ECR:**

    ```bash
    docker tag iot-simulator:latest <ECR_REPOSITORY_URL>:latest
    docker push <ECR_REPOSITORY_URL>:latest
    ```

4.  **Force Deployment (Code Updates):**
    If you update the application code but keep the image tag as `latest`, Terraform will not detect a change because the Task Definition remains identical. To force ECS to pull the newly pushed image and restart the containers without changing infrastructure, run:

    ```bash
    aws ecs update-service \
        --cluster grp1-ce11-dev-iot-cluster \
        --service dev-iot-service \
        --force-new-deployment \
        --region us-east-1
    ```

-----

### **3. Monitoring & Validation**

**1. Health Checks**
Run the automated health check script to validate containers, endpoints, and logs.

```bash
./terraform/resources/scripts/healthcheck.sh
```

**2. Dashboard Access**

  * **Grafana:** Access at `http://<ALB_DNS_NAME>/`.
      * *Default Login:* `admin` / `admin`.
      * *Dashboards:* Check "IoT Simulator Anomalies" and "System Health".
  * **Prometheus:** Access at `http://<ALB_DNS_NAME>/prometheus`.

**3. Metric Verification**
Run the validation script to confirm metrics are being scraped.

```bash
./terraform/resources/scripts/validate_prometheus.sh
```

-----

### **4. Troubleshooting Log**

The following critical issues were encountered and resolved during the implementation phase.

#### **Issue 1: DynamoDB State Locking Failure**

  * **Symptom:** `terraform apply` failed immediately with `ResourceNotFoundException`.
  * **Error Message:** `Error acquiring the state lock: Unable to retrieve item from DynamoDB table "grp1-ce11-dev-iot-locks": ... Requested resource not found`.
  * **Root Cause:** The `backend.tf` configuration expected a table named `grp1-ce11-dev-iot-locks`, but the bootstrap script created a generic table named `terraform-locks`.
  * **Resolution:** Manually created the specific table required by the configuration:
    ```bash
    aws dynamodb create-table \
        --table-name grp1-ce11-dev-iot-locks \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region us-east-1
    ```

#### **Issue 2: Environment Rehydration (Missing Dependencies)**

  * **Context:** The AWS lab environment was reset, deleting external dependencies (Secrets, Key Pairs) that Terraform does not manage directly.
  * **Symptom:** Potential `ResourceInitializationError` in ECS (due to missing secrets) or EC2 creation failure (due to missing key pair).
  * **Resolution:** Established a "Rehydration Procedure" using the helper scripts documented in Section 1.3:
    1.  Ran `./ensure-grafana-smtp-secret.sh` to restore the `grafana/smtp` secret.
    2.  Ran `./create_keypair.sh` to restore the `grp1-ec2-keypair`.

#### **Issue 3: ALB Routing Conflict (Grafana vs. Prometheus)**

  * **Symptom:** Accessing `http://<ALB_DNS>/prometheus` resulted in a Grafana 404 page instead of the Prometheus UI.
  * **Root Cause:** The ALB Listener Rules had conflicting priorities. The Grafana "catch-all" rule (`path_pattern = "/*"`) had a higher priority (lower number) than the Prometheus rule (`path_pattern = "/prometheus/*"`), shadowing it.
  * **Resolution:**
    1.  Updated `modules/iot-simulator-ecs/main.tf` to assign **Priority 90** to Prometheus and **Priority 100** to Grafana.
    2.  Updated Prometheus container configuration to include `--web.external-url=/prometheus/` and `--web.route-prefix=/prometheus/`.
    3.  Removed duplicate listener rules from the `shared-alb` module to prevent state conflicts.
