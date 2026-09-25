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
                    echo "===== Files ====="
                    ls -la
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=nutriflow \
                          -Dsonar.projectName=NutriFlow \
                          -Dsonar.sources=backend,frontend \
                          -Dsonar.exclusions=**/node_modules/**,**/dist/**,**/build/**
                    '''
                }
            }
        }

        stage('Verify Docker') {
            steps {
                sh '''
                    echo "===== Docker Version ====="
                    docker --version
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
