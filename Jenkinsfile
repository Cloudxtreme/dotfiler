pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'bundler install --path=vendor/'
            }
        }

        stage('Test') {
            steps {
                sh 'bundler exec rspec'
            }
        }
    }
}
