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
            echo 'NutriFlow test pipeline completed successfully!'
        }

        failure {
            echo 'NutriFlow test pipeline failed.'
        }
    }
}