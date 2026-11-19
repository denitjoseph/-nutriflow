
pipeline {
    agent any

    options {
        timestamps()
        skipDefaultCheckout(true)
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'FRONTEND_API_URL',
            defaultValue: 'http://localhost:8000/nutriflow',
            description: 'Backend API URL baked into frontend build'
        )
    }

    environment {
        AWS_REGION       = 'ap-south-1'
        AWS_ACCOUNT_ID   = '208805232757'
        ECR_REGISTRY     = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        BACKEND_IMAGE    = 'nutriflow-backend'
        FRONTEND_IMAGE   = 'nutriflow-frontend'
        IMAGE_TAG        = "${BUILD_NUMBER}"

        GIT_REPO_URL    = 'github.com/denitjoseph/-nutriflow.git'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Source code checked out successfully."
            }
        }

        stage('Verify Environment') {
            steps {
                sh '''
                    set -e
                    echo "===== Project Files ====="
                    pwd
                    ls -la

                    echo "===== Tool Versions ====="
                    aws --version || true
                    docker --version
                    docker compose version
                    git --version
                '''
            }
        }

        stage('Semgrep SAST Scan') {
            steps {
                sh '''
                    set -e
                    echo "===== Running Semgrep SAST Scan ====="
                    docker run --rm \
                      -v "$(pwd):/src" \
                      -w /src \
                      semgrep/semgrep \
                      semgrep scan \
                      --config auto \
                      --error \
                      backend frontend
                '''
            }
        }

        stage('Trivy SCA - Filesystem') {
            steps {
                sh '''
                    set -e
                    echo "===== Running Trivy Filesystem Scan ====="
                    docker run --rm \
                      -v "$(pwd):/root/project" \
                      -v trivy-cache:/root/.cache/ \
                      aquasec/trivy fs \
                      --scanners vuln \
                      --skip-dirs "**/node_modules" \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 \
                      /root/project
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    script {
                        def scannerHome = tool 'SonarQubeScanner'

                        sh """
                            set -e
                            echo "===== Running SonarQube Scanner ====="
                            ${scannerHome}/bin/sonar-scanner \
                              -Dsonar.projectKey=NutriFlow \
                              -Dsonar.projectName=NutriFlow \
                              -Dsonar.sources=backend,frontend \
                              -Dsonar.exclusions=**/node_modules/**,**/dist/**,**/build/**,**/*.png,**/*.jpg,**/*.jpeg,**/*.svg
                        """
                    }
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                sh """
                    set -e

                    echo "===== Building Backend Docker Image ====="
                    docker build \
                      -t ${BACKEND_IMAGE}:latest \
                      -t ${BACKEND_IMAGE}:${IMAGE_TAG} \
                      -t ${ECR_REGISTRY}/${BACKEND_IMAGE}:${IMAGE_TAG} \
                      -t ${ECR_REGISTRY}/${BACKEND_IMAGE}:latest \
                      ./backend

                    echo "===== Building Frontend Docker Image ====="
                    docker build \
                      --build-arg VITE_API_URL=${params.FRONTEND_API_URL} \
                      -t ${FRONTEND_IMAGE}:latest \
                      -t ${FRONTEND_IMAGE}:${IMAGE_TAG} \
                      -t ${ECR_REGISTRY}/${FRONTEND_IMAGE}:${IMAGE_TAG} \
                      -t ${ECR_REGISTRY}/${FRONTEND_IMAGE}:latest \
                      ./frontend

                    echo "===== Local Images Built ====="
                    docker images | grep -E "${BACKEND_IMAGE}|${FRONTEND_IMAGE}"
                """
            }
        }

        stage('Trivy SCA - Container Images') {
            steps {
                sh '''
                    set -e

                    echo "===== Scanning Backend Docker Image ====="
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v trivy-cache:/root/.cache/ \
                      aquasec/trivy image \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 \
                      ${BACKEND_IMAGE}:${IMAGE_TAG}

                    echo "===== Scanning Frontend Docker Image ====="
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v trivy-cache:/root/.cache/ \
                      aquasec/trivy image \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 \
                      ${FRONTEND_IMAGE}:${IMAGE_TAG}
                '''
            }
        }

        stage('OWASP ZAP DAST Scan') {
            steps {
                sh '''
                    set -e

                    echo "===== Starting NutriFlow Containers for DAST ====="
                    docker compose up -d

                    echo "===== Waiting for Services ====="
                    sleep 15

                    curl -fsS http://localhost:8000/nutriflow || echo "Backend ping checked"
                    curl -fsS http://localhost:5173 || echo "Frontend ping checked"

                    mkdir -p zap-reports
                    chmod 777 zap-reports || true

                    echo "===== Running ZAP DAST on Backend ====="
                    docker run --rm \
                      --network host \
                      -v "$(pwd)/zap-reports:/zap/wrk:rw" \
                      zaproxy/zap-stable zap-baseline.py \
                      -t http://localhost:8000/nutriflow \
                      -r zap-backend-report.html \
                      -I || true

                    echo "===== Running ZAP DAST on Frontend ====="
                    docker run --rm \
                      --network host \
                      -v "$(pwd)/zap-reports:/zap/wrk:rw" \
                      zaproxy/zap-stable zap-baseline.py \
                      -t http://localhost:5173 \
                      -r zap-frontend-report.html \
                      -I || true

                    echo "===== Stopping DAST Test Containers ====="
                    docker compose down
                '''
            }
        }

        stage('Push Images to AWS ECR') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'aws-access-key-id',
                        variable: 'AWS_ACCESS_KEY_ID'
                    ),
                    string(
                        credentialsId: 'aws-secret-access-key',
                        variable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set -e

                        export AWS_DEFAULT_REGION=${AWS_REGION}

                        echo "===== Logging into AWS ECR ====="
                        aws ecr get-login-password --region ${AWS_REGION} | \
                          docker login \
                          --username AWS \
                          --password-stdin \
                          ${ECR_REGISTRY}

                        echo "===== Pushing Backend to ECR ====="
                        docker push ${ECR_REGISTRY}/${BACKEND_IMAGE}:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${BACKEND_IMAGE}:latest

                        echo "===== Pushing Frontend to ECR ====="
                        docker push ${ECR_REGISTRY}/${FRONTEND_IMAGE}:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${FRONTEND_IMAGE}:latest

                        echo "===== ECR Push Completed Successfully ====="
                    '''
                }
            }
        }

        stage('Update Manifests for Argo CD') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_TOKEN'
                    )
                ]) {
                    sh '''
                        set -e

                        echo "===== Updating Kubernetes Manifests ====="

                        sed -i "s|image: .*/nutriflow-backend:.*|image: ${ECR_REGISTRY}/${BACKEND_IMAGE}:${IMAGE_TAG}|g" k8s/backend.yaml

                        sed -i "s|image: .*/nutriflow-frontend:.*|image: ${ECR_REGISTRY}/${FRONTEND_IMAGE}:${IMAGE_TAG}|g" k8s/frontend.yaml

                        echo "===== Committing Changes ====="

                        git config user.name "jenkins-bot"
                        git config user.email "jenkins@nutriflow.local"

                        git add k8s/backend.yaml k8s/frontend.yaml

                        if git diff --staged --quiet; then
                            echo "No changes in manifests to commit."
                        else
                            git commit -m "chore(gitops): update image tags to ${IMAGE_TAG} [skip ci]"

                            echo "===== Pushing to Git Repository ====="

                            git push https://${GIT_USERNAME}:${GIT_TOKEN}@${GIT_REPO_URL} HEAD:main

                            echo "===== Manifests Updated for Argo CD ====="
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                echo "===== Jenkins Workspace Cleanup ====="
                docker image prune -f || true
            '''

            archiveArtifacts artifacts: 'zap-reports/*.html',
                            allowEmptyArchive: true
        }

        success {
            echo "NutriFlow Pipeline #${BUILD_NUMBER} completed successfully!"
        }

        failure {
            echo "NutriFlow Pipeline #${BUILD_NUMBER} failed."
        }
    }
}
