# 🥗 NutriFlow — Cloud-Native Nutrition Platform & DevSecOps GitOps Pipeline

[![CI/CD Pipeline](https://img.shields.io/badge/Jenkins-CI%2FCD-red?logo=jenkins)](https://jenkins.io)
[![GitOps](https://img.shields.io/badge/GitOps-Argo%20CD-orange?logo=argo)](https://argoproj.github.io/cd/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-AWS%20EKS-blue?logo=kubernetes)](https://aws.amazon.com/eks/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple?logo=terraform)](https://terraform.io)
[![Security](https://img.shields.io/badge/Security-SAST%20%7C%20SCA%20%7C%20DAST-green?logo=shield)](#-devsecops-security-pipeline)
[![Monitoring](https://img.shields.io/badge/Monitoring-Prometheus%20%26%20Grafana-critical?logo=prometheus)](./monitoring/prometheus.yml)

NutriFlow is a full-stack, cloud-native nutrition and meal subscription management platform built with enterprise-grade **DevSecOps**, **CI/CD automation**, **Infrastructure as Code (IaC)**, and **GitOps deployment** to **AWS EKS**.

---

## 📑 Table of Contents
- [Architecture Overview](#-architecture-overview)
- [Tech Stack](#-tech-stack)
- [DevSecOps Security Pipeline](#-devsecops-security-pipeline)
- [Quick Start (Local Development)](#-quick-start-local-development)
- [CI/CD Pipeline (Jenkins)](#-cicd-pipeline-jenkins)
- [GitOps with Argo CD & EKS](#-gitops-with-argo-cd--eks)
- [Infrastructure as Code (Terraform)](#-infrastructure-as-code-terraform)
- [Monitoring & Observability](#-monitoring--observability)
- [Clean Teardown (Cost Optimization)](#-clean-teardown-cost-optimization)

---

## 🏛 Architecture Overview

```mermaid
flowchart TD
    subgraph Developer Workspace
        DEV[Developer] -->|Git Push| GITHUB[GitHub Repository]
    end

    subgraph CI / DevSecOps Engine (Jenkins on EC2)
        GITHUB -->|Webhook / Poll| JNK[Jenkins CI Pipeline]
        JNK --> SG[Semgrep SAST]
        JNK --> TRV_FS[Trivy SCA Filesystem]
        JNK --> SQ[SonarQube Quality Gate]
        JNK --> BUILD[Docker Multi-Stage Build]
        JNK --> TRV_IMG[Trivy Image Scan]
        JNK --> ZAP[OWASP ZAP DAST Scan]
        JNK -->|Push Images| ECR[(AWS ECR)]
        JNK -->|Update k8s/ Image Tag| GITHUB
    end

    subgraph GitOps CD (AWS EKS Cluster)
        GITHUB -.->|Detects New Commit| ARGO[Argo CD]
        ARGO -->|Syncs Manifests| EKS[Amazon EKS Cluster]
        
        subgraph NutriFlow Namespace
            EKS --> FE_PODS[Frontend Pods: Nginx + React]
            EKS --> BE_PODS[Backend Pods: Node.js Express]
            EKS --> DB_POD[MongoDB Pod: 7.0]
        end
    end

    subgraph Monitoring & Metrics
        BE_PODS -->|Exposes /nutriflow/metrics| PROM[Prometheus]
        PROM --> GRAF[Grafana Dashboards]
    end
```

---

## 🛠 Tech Stack

| Domain | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | React 18, Vite, Tailwind CSS, Lucide Icons | Responsive meal planning & dietary tracking UI |
| **Backend** | Node.js, Express.js, Mongoose | RESTful API, authentication, order processing |
| **Database** | MongoDB 7.0 | Document store for meal plans, users, orders |
| **Web Server** | Nginx Alpine (Slim, Non-Root) | Production static asset server & reverse proxy |
| **CI / CD** | Jenkins (Declarative Pipeline on EC2) | Automated build, security scan, and push pipeline |
| **SAST** | Semgrep | Static code analysis & vulnerability detection |
| **SCA** | Aquasec Trivy | Open-source dependency & container image scanning |
| **Code Quality** | SonarQube Scanner + Quality Gate | Code coverage, maintainability, and code smells |
| **DAST** | OWASP ZAP (Baseline Scan) | Live application dynamic vulnerability scanner |
| **Container Registry**| AWS ECR | Private Docker image registry with scan-on-push |
| **GitOps** | Argo CD | Continuous delivery and state reconciliation in K8s |
| **Orchestration**| Amazon EKS (Kubernetes v1.33) | Multi-AZ managed container orchestration |
| **IaC** | Terraform (AWS Provider v6.x) | Automated VPC, Subnets, EKS, Node Groups, IAM |
| **Observability** | Prometheus (`prom-client`) + Grafana | Application metrics scraping and visual dashboards |

---

## 🛡 DevSecOps Security Pipeline

NutriFlow integrates security checks across every phase of development:

1. **SAST (Static Application Security Testing)**:
   * **Tool**: `semgrep/semgrep`
   * **Scope**: Scans both backend and frontend source directories for ReDoS, injection, and insecure API usage.
2. **SCA (Software Composition Analysis)**:
   * **Tool**: `aquasec/trivy fs`
   * **Scope**: Scans `package-lock.json` dependencies for HIGH and CRITICAL CVEs, skipping `node_modules` for performance.
3. **Static Code Quality & Standards**:
   * **Tool**: SonarQube Scanner
   * **Scope**: Enforces quality gates for technical debt, duplication, and code smells.
4. **Container Image Hardening**:
   * **Tool**: `aquasec/trivy image`
   * **Scope**: Inspects final Docker images (`nutriflow-backend` & `nutriflow-frontend`) for base OS vulnerabilities.
5. **DAST (Dynamic Application Security Testing)**:
   * **Tool**: `zaproxy/zap-stable`
   * **Scope**: Runs automated baseline scans against live containers on port 8000 and 5173, exporting HTML reports.
6. **Container Security Standards**:
   * Both frontend and backend run as **non-root users** (`nginx` user on port 8080, `node` user on port 8000).
   * Strict HTTP security headers configured: `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`.

---

## 💻 Quick Start (Local Development)

### Prerequisites
- Docker & Docker Compose
- Node.js 20+

### 1. Clone the Repository
```bash
git clone https://github.com/denitjoseph/-nutriflow.git
cd -nutriflow
```

### 2. Run All Services with Docker Compose
```bash
docker compose up -d --build
```

### 3. Access Local Endpoints
- **Frontend UI**: [http://localhost:5173](http://localhost:5173)
- **Backend API**: [http://localhost:8000/nutriflow](http://localhost:8000/nutriflow)
- **Metrics Endpoint**: [http://localhost:8000/nutriflow/metrics](http://localhost:8000/nutriflow/metrics)
- **Prometheus UI**: [http://localhost:9090](http://localhost:9090)
- **Grafana UI**: [http://localhost:3000](http://localhost:3000) *(Credentials: `admin` / `admin`)*

---

## ⚙ CI/CD Pipeline (Jenkins)

The pipeline is fully automated in [`Jenkinsfile`](./Jenkinsfile) and includes 17 sequential stages:

```text
1. Checkout                -> Checks out source code from Git
2. Verify Environment      -> Verifies aws, docker, compose, and git versions
3. Semgrep SAST Scan       -> Static security scan on source code
4. Trivy SCA Scan          -> Scans project dependencies for CVEs
5. SonarQube Analysis      -> Runs SonarQube scanner for code quality
6. SonarQube Quality Gate  -> Verifies quality gate status
7. Build Docker Images     -> Multi-stage builds for backend and frontend
8. Trivy Image Scan        -> Vulnerability scanning on container images
9. OWASP ZAP DAST Scan     -> Dynamic testing against live test containers
10. Push Images to ECR     -> Logs into ECR via EC2 IAM Role and pushes tags
11. Update Manifests       -> Updates k8s/ image tags with ${BUILD_NUMBER} and commits back to Git
```

---

## 🐙 GitOps with Argo CD & EKS

NutriFlow uses the **GitOps pattern**:
1. When the Jenkins pipeline completes successfully, it automatically edits `k8s/backend.yaml` and `k8s/frontend.yaml` with the new `${BUILD_NUMBER}` image tag.
2. Jenkins commits and pushes this change to the `main` branch with `[skip ci]`.
3. **Argo CD** detects the updated commit and automatically reconciles the state on the AWS EKS cluster with zero downtime (Rolling Updates).

### Kubernetes Manifests (`k8s/`):
- `namespace.yaml`: Creates dedicated `nutriflow` namespace.
- `mongodb.yaml`: MongoDB 7.0 deployment and ClusterIP service.
- `backend.yaml`: Scalable backend deployment (2 replicas) with readiness and liveness probes.
- `frontend.yaml`: Nginx frontend deployment (2 replicas) and NodePort/LoadBalancer service.
- `argocd-app.yaml`: Argo CD Application definition for automated continuous deployment.

---

## 🌍 Infrastructure as Code (Terraform)

All AWS infrastructure is managed under [`devops/terraform/`](./devops/terraform):

```text
devops/terraform/
├── provider.tf     # AWS provider & minimum version constraints
├── variables.tf    # Regional and sizing parameters
├── vpc.tf          # Multi-AZ VPC, public/private subnets, NAT Gateway
├── ecr.tf          # Private backend and frontend ECR repositories
├── iam.tf          # EC2 instance profile, ECR PowerUser, & EKS admin policies
├── eks.tf          # AWS EKS cluster, managed node groups, and addons
└── outputs.tf      # Cluster endpoints, subnet IDs, and repository URLs
```

### Deploying Infrastructure:
```bash
cd devops/terraform
terraform init
terraform apply -auto-approve
```

### Connecting to Cluster:
```bash
aws eks update-kubeconfig --region ap-south-1 --name nutriflow-eks
kubectl get nodes
```

---

## 📊 Monitoring & Observability

- **Application Metrics**: Node.js `prom-client` exports Prometheus-compatible metrics at `/nutriflow/metrics` (HTTP request duration, memory usage, CPU usage, event loop lag).
- **Prometheus**: Automatically scrapes the backend service every 15 seconds.
- **Grafana**: Pre-configured dashboards for real-time visualization of container throughput and latency.

---

## 🧹 Clean Teardown (Cost Optimization)

To cleanly destroy all AWS resources and avoid unnecessary charges:

```bash
# 1. Delete Kubernetes Load Balancers & Namespaces first
kubectl delete svc argocd-server -n argocd
kubectl delete namespace nutriflow --wait=false
kubectl delete namespace argocd --wait=false
sleep 60

# 2. Destroy Terraform Resources
cd devops/terraform
terraform destroy -auto-approve

# 3. Terminate EC2 Jenkins Instance via AWS Console
```

---

## 👥 Contributors & Acknowledgements

- **Repository Owner**: [denitjoseph](https://github.com/denitjoseph)
- **Project**: NutriFlow Cloud-Native Platform
