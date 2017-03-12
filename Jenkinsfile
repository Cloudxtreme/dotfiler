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
                archiveArtifacts artifacts: 'coverage/*'
            }
        }

        stage('Document') {
            steps {
                sh 'bundler exec rake yard'
                archiveArtifacts artifacts: 'doc/*'
            }
        }
    }
}
