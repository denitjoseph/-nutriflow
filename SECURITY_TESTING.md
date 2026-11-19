# 🛡️ NutriFlow Security & DevSecOps Testing Guide

This guide outlines the logical workflow to test **Semgrep (SAST)**, **Trivy (SCA)**, and **OWASP ZAP (DAST)** locally on your machine using Docker.

---

## 📋 Logical Testing Sequence

```
  ┌─────────────────────────────────────────────────────────┐
  │  Phase 1: Spin Up Application (Docker Compose)         │
  └────────────────────────┬────────────────────────────────┘
                           │
  ┌────────────────────────▼────────────────────────────────┐
  │  Phase 2: SAST (Semgrep) — Source Code Security Scan    │
  └────────────────────────┬────────────────────────────────┘
                           │
  ┌────────────────────────▼────────────────────────────────┐
  │  Phase 3: SCA (Trivy) — Dependencies & Image Vulnerability│
  └────────────────────────┬────────────────────────────────┘
                           │
  ┌────────────────────────▼────────────────────────────────┐
  │  Phase 4: DAST (OWASP ZAP) — Live Endpoint Security Scan│
  └────────────────────────┬────────────────────────────────┘
                           │
  ┌────────────────────────▼────────────────────────────────┐
  │  Phase 5: Review Reports & Teardown                     │
  └─────────────────────────────────────────────────────────┘
```

---

## 🚀 Phase 1: Spin Up the Application

DAST requires active, listening services. Before running dynamic tests, ensure all containers are running and healthy.

```powershell
# 1. Build and start MongoDB, Backend, and Frontend
docker compose up -d --build

# 2. Verify all 3 containers are healthy and running
docker compose ps
```

**Expected Status:**
- `nutriflow-mongodb`: `Up (healthy)`
- `nutriflow-backend`: `Up` on `0.0.0.0:8000`
- `nutriflow-frontend`: `Up` on `0.0.0.0:5173`

---

## 🔍 Phase 2: SAST — Static Application Security Testing (Semgrep)

**Goal:** Scan the source code for hardcoded secrets, injection flaws (SQL/NoSQL/Command), and insecure programming patterns.

### 1. Run Complete Project Scan
```powershell
docker run --rm -v "${PWD}:/src" returntocorp/semgrep semgrep scan --config auto
```

### 2. Export Output to JSON Report
```powershell
docker run --rm -v "${PWD}:/src" returntocorp/semgrep semgrep scan --config auto --json -o /src/semgrep-report.json
```

### 3. (Optional) Scan Individual Components
```powershell
# Scan Backend only
docker run --rm -v "${PWD}:/src" returntocorp/semgrep semgrep scan --config auto /src/backend

# Scan Frontend only
docker run --rm -v "${PWD}:/src" returntocorp/semgrep semgrep scan --config auto /src/frontend
```

---

## 📦 Phase 3: SCA — Software Composition Analysis (Trivy)

**Goal:** Detect known vulnerabilities (CVEs) in third-party npm packages and OS packages in your Docker base images.

### 1. Scan Project Dependencies (Filesystem Scan)
Scans `package.json` and `package-lock.json` for known vulnerabilities (skipping heavy node_modules directories and using a persistent cache volume):
```powershell
docker run --rm -v "${PWD}:/root/project" -v trivy-cache:/root/.cache/ aquasec/trivy fs --scanners vuln --skip-dirs "**/node_modules" --severity HIGH,CRITICAL /root/project
```

### 2. Scan Built Docker Images
Inspects the container filesystem and runtime packages (`node:22-slim`, `nginx:alpine-slim`):

```powershell
# Scan Backend Image
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ aquasec/trivy image --severity HIGH,CRITICAL nutriflow-backend:latest

# Scan Frontend Image
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ aquasec/trivy image --severity HIGH,CRITICAL nutriflow-frontend:latest
```

---

## ⚡ Phase 4: DAST — Dynamic Application Security Testing (OWASP ZAP)

**Goal:** Simulate external attacks against running HTTP endpoints to detect missing security headers, sensitive info disclosure, CORS misconfigurations, and cookie vulnerabilities.

### 1. Create Reports Directory
```powershell
New-Item -ItemType Directory -Force -Path "zap-reports"
```

### 2. Scan Backend API
Points ZAP at the backend API running via Docker (`http://host.docker.internal:8000`):
```powershell
docker run --rm -t -v "${PWD}/zap-reports:/zap/wrk" zaproxy/zap-stable zap-baseline.py `
  -t http://host.docker.internal:8000/nutriflow `
  -r zap-backend-report.html `
  -I
```

### 3. Scan Frontend Application
Points ZAP at the Nginx frontend web server (`http://host.docker.internal:5173`):
```powershell
docker run --rm -t -v "${PWD}/zap-reports:/zap/wrk" zaproxy/zap-stable zap-baseline.py `
  -t http://host.docker.internal:5173 `
  -r zap-frontend-report.html `
  -I
```

> **Note:** The `-I` flag tells ZAP to report non-zero warnings without failing the test run.

---

## 📊 Phase 5: Review Results

All generated reports will be stored in your project directory:

| Test Layer | Output File | Format |
| :--- | :--- | :--- |
| **SAST (Semgrep)** | `semgrep-report.json` | JSON |
| **SCA (Trivy)** | Terminal console output | Text / Table |
| **DAST (OWASP ZAP)** | `zap-reports/zap-backend-report.html` | Interactive HTML |
| **DAST (OWASP ZAP)** | `zap-reports/zap-frontend-report.html` | Interactive HTML |

To view the HTML reports, simply double-click them or run:
```powershell
Invoke-Item zap-reports/zap-backend-report.html
Invoke-Item zap-reports/zap-frontend-report.html
```

---

## 🧹 Phase 6: Teardown

When testing is complete, stop the application services:

```powershell
docker compose down
```
