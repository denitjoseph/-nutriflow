# NutriFlow: Complete EC2, Jenkins, IAM & EKS Setup Guide

This guide provides the complete, end-to-end instructions for deploying NutriFlow on an **AWS EC2 instance**, configuring **IAM roles**, installing **Jenkins, Docker, SonarQube, and security tools**, and connecting everything to **AWS ECR, EKS, and Argo CD**.

---

## Table of Contents
1. [Architectural Decision: IAM Role vs. AWS Credentials](#1-architectural-decision-iam-role-vs-aws-credentials)
2. [EC2 Instance Sizing & Security Group Setup](#2-ec2-instance-sizing--security-group-setup)
3. [IAM Role & Permissions (Terraform Automated)](#3-iam-role--permissions-terraform-automated)
4. [Step-by-Step EC2 Setup (Commands to Run on EC2)](#4-step-by-step-ec2-setup-commands-to-run-on-ec2)
5. [Running SonarQube on EC2](#5-running-sonarqube-on-ec2)
6. [Configuring Jenkins Plugins & Credentials](#6-configuring-jenkins-plugins--credentials)
7. [What to Change in `Jenkinsfile` (IPs, Ports, & Git)](#7-what-to-change-in-jenkinsfile-ips-ports--git)
8. [Connecting EKS, Argo CD, and Prometheus](#8-connecting-eks-argo-cd-and-prometheus)

---

## 1. Architectural Decision: IAM Role vs. AWS Credentials

### Which is better: IAM Role or AWS Access Keys?
> **Always use an IAM Role attached to the EC2 instance (Instance Profile).**

| Feature | EC2 IAM Role (Recommended) | AWS Access Keys (`credentials`) |
| :--- | :--- | :--- |
| **Security** | **Highest**: No credentials stored on disk or in Jenkins. | **Low**: Long-lived secret keys stored in plaintext or Jenkins store. |
| **Rotation** | **Automatic**: AWS rotates temporary STS tokens every few hours. | **Manual**: Keys never rotate unless you rotate them manually. |
| **Leak Risk** | **Zero**: Cannot be accidentally committed to Git. | **High**: Risk of leaking keys into Git commits or build logs. |
| **Maintenance** | **Zero**: AWS CLI and SDKs automatically detect the role. | **High**: Must update Jenkins credentials if keys expire. |

---

## 2. EC2 Instance Sizing & Security Group Setup

### Recommended EC2 Specifications
Running **Jenkins**, **Docker builds**, **SonarQube**, and **OWASP ZAP** simultaneously requires adequate CPU and RAM:
- **Instance Type**: `t3.large` (2 vCPU, 8 GB RAM) or `t3.xlarge` (4 vCPU, 16 GB RAM)
- **AMI**: Ubuntu Server 24.04 LTS (HVM) or Amazon Linux 2023
- **Storage**: **30 GB to 50 GB gp3 SSD** (Docker images and SonarQube indices consume disk space)

### Security Group Inbound Rules
Configure your EC2 Security Group with these inbound ports:

| Type | Port Range | Source | Purpose |
| :--- | :--- | :--- | :--- |
| **SSH** | `22` | `My IP` | Secure terminal access |
| **Custom TCP** | `8080` | `My IP` or `0.0.0.0/0` | Jenkins Web Console |
| **Custom TCP** | `9000` | `My IP` or `0.0.0.0/0` | SonarQube Web Console |
| **Custom TCP** | `8000` | `0.0.0.0/0` | NutriFlow Backend API |
| **Custom TCP** | `5173` | `0.0.0.0/0` | NutriFlow Frontend UI |
| **Custom TCP** | `3000` | `My IP` | Grafana Dashboard |
| **Custom TCP** | `9090` | `My IP` | Prometheus Dashboard |

---

## 3. IAM Role & Permissions (Terraform Automated)

### Why EKS Cluster Creation Fails with IAM Permission Denial
When creating an EKS cluster with Terraform, AWS requires far more than just basic EKS permissions:
1. **`iam:PassRole`**: To create the cluster, your identity must pass the cluster IAM role to the EKS service. If `iam:PassRole` is missing, AWS immediately returns `AccessDeniedException`.
2. **`iam:CreateRole` & `iam:AttachRolePolicy`**: The EKS Terraform module automatically creates the Cluster IAM role, Node Group IAM role, and OIDC provider roles. If the executing identity lacks IAM permissions, it fails before creating the cluster.
3. **`eks:CreateCluster` & VPC/EC2 APIs**: Full permissions to create the cluster and attach security groups in private subnets.
4. **Kubernetes API Access Entries**: In Kubernetes 1.29+, EKS uses Access Entries instead of the old `aws-auth` ConfigMap. If not configured, `kubectl` will return `Unauthorized / AccessDenied`.

### What We Have Fixed in Terraform:
- **`AdministratorAccess` attached in `devops/terraform/iam.tf`**: If you run Terraform from the EC2 instance, it will have zero IAM denials when creating VPCs, EKS clusters, Node Groups, and IAM roles.
- **`enable_cluster_creator_admin_permissions = true` in `eks.tf`**: Automatically makes whoever runs `terraform apply` a `cluster-admin`.
- **`access_entries` mapped to `jenkins_role` in `eks.tf`**: Grants the Jenkins EC2 IAM Role `AmazonEKSClusterAdminPolicy` inside Kubernetes so Jenkins and Argo CD can manage pods and deployments without authentication errors.

### Permissions Included:
1. **`AdministratorAccess`**:
   - Ensures running `terraform apply` on EC2 has complete rights to create VPC, Subnets, NAT Gateways, EKS control plane, managed node groups, and IAM roles without `iam:PassRole` or `eks:CreateCluster` denial.
2. **`AmazonEC2ContainerRegistryPowerUser`**:
   - Allows Jenkins to authenticate (`aws ecr get-login-password`), pull base images, build, tag, and push Docker images to your private ECR repositories.
3. **`jenkins-eks-policy`** (Custom):
   - Grants permissions for `eks:DescribeCluster`, `eks:ListClusters`, and `eks:AccessKubernetesApi` to verify cluster health and update `kubeconfig`.
4. **`jenkins-instance-profile`**:
   - The AWS IAM Instance Profile that attaches directly to your EC2 instance.

### Attaching the IAM Role to EC2:
- **Via AWS Management Console**:
  1. Open **EC2 Console** -> **Instances** -> Select your Jenkins EC2 instance.
  2. Click **Actions** -> **Security** -> **Modify IAM Role**.
  3. Select `nutriflow-jenkins-instance-profile` (or `nutriflow-jenkins-ec2-role`).
  4. Click **Update IAM Role**.

---

## 4. Step-by-Step EC2 Setup (Commands to Run on EC2)

Connect to your EC2 instance via SSH:
```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

Run the following commands sequentially:

### Step 4.1: Update System Packages
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git unzip jq apt-transport-https ca-certificates gnupg lsb-release
```

### Step 4.2: Install AWS CLI v2
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip ./aws

# Verify IAM Role is working without entering any keys:
aws sts get-caller-identity
```
*(If the output displays your IAM role ARN, authentication is working!)*

### Step 4.3: Install Docker & Docker Compose
```bash
# Add Docker official GPG key & repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Grant ubuntu user access to docker
sudo usermod -aG docker ubuntu
```

### Step 4.4: Install Java 17 (Required for Jenkins & SonarQube Scanner)
```bash
sudo apt install -y openjdk-17-jdk
java -version
```

### Step 4.5: Install Jenkins
```bash
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins

# Add jenkins user to docker group so pipeline can execute docker commands:
sudo usermod -aG docker jenkins

# Enable and restart Jenkins
sudo systemctl enable jenkins
sudo systemctl restart jenkins
```

### Step 4.6: Install Kubectl & Terraform (Optional on EC2)
```bash
# Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

---

## 5. Running SonarQube on EC2

The fastest and most reliable way to run SonarQube on EC2 is via Docker:

```bash
docker run -d --name sonarqube \
  -p 9000:9000 \
  --restart always \
  sonarqube:lts-community
```

1. Open your browser and navigate to: `http://<EC2_PUBLIC_IP>:9000`
2. Default login credentials:
   - **Username**: `admin`
   - **Password**: `admin` *(You will be prompted to set a new password).*
3. Create a Project:
   - Click **Manually create project** -> Project Key: `NutriFlow` -> Project Name: `NutriFlow`.
4. Generate a Token:
   - Go to **My Account** -> **Security** -> **Generate Tokens**.
   - Type: `Global Analysis Token` -> Name: `jenkins-sonar-token`. Copy this token!
5. Add Webhook for Quality Gate:
   - In SonarQube, go to **Administration** -> **Configuration** -> **Webhooks**.
   - Click **Create**:
     - **Name**: `Jenkins-Webhook`
     - **URL**: `http://<EC2_PRIVATE_OR_PUBLIC_IP>:8080/sonarqube-webhook/`

---

## 6. Configuring Jenkins Plugins & Credentials

1. Open Jenkins in your browser: `http://<EC2_PUBLIC_IP>:8080`
2. Retrieve initial admin password:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
3. Install Suggested Plugins, then install additional plugins under **Manage Jenkins** -> **Plugins**:
   - **SonarQube Scanner**
   - **Pipeline: Stage View**
   - **Timestamper**
4. Configure SonarQube in Jenkins:
   - Go to **Manage Jenkins** -> **System** -> Under **SonarQube servers**:
     - Name: `SonarQube`
     - Server URL: `http://localhost:9000` (or `http://<EC2_PRIVATE_IP>:9000`)
     - Server authentication token: Add Secret Text credential with your SonarQube token.
   - Go to **Manage Jenkins** -> **Tools** -> Under **SonarQube Scanner installations**:
     - Name: `SonarQubeScanner`
     - Check **Install automatically**.
5. Add Git Credentials:
   - Go to **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials** -> **Add Credentials**:
     - Kind: **Username with password**
     - ID: `git-credentials`
     - Username: Your GitLab/GitHub username
     - Password: Your Personal Access Token (with repository `write` permissions).

---

## 7. What to Change in `Jenkinsfile` (IPs, Ports, & Git)

Open `Jenkinsfile` in your repository. Here are the variables you should review:

```groovy
parameters {
    string(
        name: 'FRONTEND_API_URL',
        defaultValue: 'http://localhost:8000/nutriflow',
        description: 'Backend API URL baked into frontend build'
    )
}

environment {
    AWS_REGION     = 'ap-south-1'               // Your AWS Region
    AWS_ACCOUNT_ID = '208805232757'             // Your AWS 12-digit Account ID
    ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    GIT_REPO_URL   = 'gitlab.com/jijojohn911/NurtiFlow.git' // Your Git repository URL
}
```

### When Changing EC2 IP or Moving to Production:
1. **Frontend API URL (`FRONTEND_API_URL`)**:
   - Vite builds a static JavaScript bundle that executes **inside the client's browser**.
   - If you test the app by opening `http://<EC2_PUBLIC_IP>:5173` from your laptop browser, the browser cannot reach `localhost:8000`.
   - In that case, trigger the Jenkins build with parameter `FRONTEND_API_URL = http://<EC2_PUBLIC_IP>:8000/nutriflow`.
   - When deployed to EKS behind an Application Load Balancer (ALB), set `FRONTEND_API_URL = http://<ALB_DNS_NAME>/nutriflow` or your custom domain (e.g. `https://api.yourdomain.com/nutriflow`).
2. **Git Repository URL (`GIT_REPO_URL`)**:
   - Ensure `GIT_REPO_URL` matches your exact repository path (without `https://` prefix, e.g. `gitlab.com/your-username/NutriFlow.git`).

---

## 8. Connecting EKS, Argo CD, and Prometheus

### Deploying Infrastructure via Terraform
From your local terminal or from the EC2 instance:
```bash
cd devops/terraform
terraform init
terraform plan
terraform apply -auto-approve
```

### Updating Kubeconfig for EKS
```bash
aws eks update-kubeconfig --region ap-south-1 --name nutriflow-eks
kubectl get nodes
```

### Installing Argo CD on EKS
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD pods to be ready
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Apply NutriFlow Argo CD Application Manifest
kubectl apply -f k8s/argocd-app.yaml

# Retrieve the initial Argo CD admin password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Accessing Prometheus & Grafana
1. The NutriFlow backend exposes metrics at `/nutriflow/metrics`.
2. When deployed via `docker-compose.yml`:
   - Prometheus is available at `http://<EC2_PUBLIC_IP>:9090`
   - Grafana is available at `http://<EC2_PUBLIC_IP>:3000` (Default credentials: `admin` / `admin`).
3. When deployed to EKS, install the Prometheus community stack:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
   ```
