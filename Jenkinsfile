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
        stage('Verify Docker') {
            steps {
                sh '''
                    echo "===== Docker Version ====="
                    docker --version

                    echo "===== Docker Access ====="
                    docker ps
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
