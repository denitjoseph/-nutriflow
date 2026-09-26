pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Project') {
            steps {
                sh '''
                    echo "===== NutriFlow Project ====="
                    pwd

                    echo "===== Project Files ====="
                    ls -la

                    echo "===== Backend ====="
                    ls -la backend

                    echo "===== Frontend ====="
                    ls -la frontend
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    script {
                        def scannerHome = tool 'SonarQubeScanner'

                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                              -Dsonar.projectKey=NutriFlow \
                              -Dsonar.projectName=NutriFlow \
                              -Dsonar.sources=backend,frontend \
                              -Dsonar.exclusions=**/node_modules/**,**/dist/**,**/build/**
                        """
                    }
                }
            }
        }

        stage('Build Backend Docker Image') {
            steps {
                sh '''
                    echo "===== Building NutriFlow Backend ====="

                    docker build \
                      -t nutriflow-backend:latest \
                      ./backend

                    echo "===== Backend Docker Image ====="
                    docker images nutriflow-backend
                '''
            }
        }

        stage('Build Frontend Docker Image') {
            steps {
                sh '''
                    echo "===== Building NutriFlow Frontend ====="

                    docker build \
                      --build-arg VITE_API_URL=http://localhost:8000/nutriflow \
                      -t nutriflow-frontend:latest \
                      ./frontend

                    echo "===== Frontend Docker Image ====="
                    docker images nutriflow-frontend
                '''
            }
        }

        stage('Verify Docker') {
            steps {
                sh '''
                    echo "===== Docker Version ====="
                    docker --version

                    echo "===== Docker Images ====="
                    docker images | grep nutriflow
                '''
            }
        }
    }

    post {
        success {
            echo 'NutriFlow pipeline completed successfully!'
        }

        failure {
            echo 'NutriFlow pipeline failed.'
        }
    }
}
