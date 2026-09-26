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

        stage('Push Images to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-ecr'
                ]]) {
                    sh '''
                        echo "===== AWS CLI Version ====="
                        aws --version

                        echo "===== AWS ECR Login ====="

                        aws ecr get-login-password \
                          --region ap-south-1 | \
                        docker login \
                          --username AWS \
                          --password-stdin \
                          208805232757.dkr.ecr.ap-south-1.amazonaws.com

                        echo "===== Tag Backend Image ====="

                        docker tag \
                          nutriflow-backend:latest \
                          208805232757.dkr.ecr.ap-south-1.amazonaws.com/nutriflow-backend:latest

                        echo "===== Push Backend Image ====="

                        docker push \
                          208805232757.dkr.ecr.ap-south-1.amazonaws.com/nutriflow-backend:latest

                        echo "===== Tag Frontend Image ====="

                        docker tag \
                          nutriflow-frontend:latest \
                          208805232757.dkr.ecr.ap-south-1.amazonaws.com/nutriflow-frontend:latest

                        echo "===== Push Frontend Image ====="

                        docker push \
                          208805232757.dkr.ecr.ap-south-1.amazonaws.com/nutriflow-frontend:latest

                        echo "===== ECR Push Completed ====="
                    '''
                }
            }
        }

        stage('Verify Docker') {
            steps {
                sh '''
                    echo "===== Docker Version ====="
                    docker --version

                    echo "===== NutriFlow Docker Images ====="
                    docker images | grep nutriflow
                '''
            }
        }
    }

    post {
        success {
            echo 'NutriFlow CI pipeline completed successfully!'
        }

        failure {
            echo 'NutriFlow CI pipeline failed.'
        }
    }
}
