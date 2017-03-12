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
                publishHTML (target: [
                    allowMissing: false,
                    alwaysLinkToLastBuild: false,
                    keepAll: true,
                    reportDir: 'coverage/',
                    reportFiles: 'index.html',
                    reportName: "Run coverage"
                ])
            }
        }

        stage('Document') {
            steps {
                sh 'bundler exec rake yard'
                archiveArtifacts artifacts: 'doc/*'
                publishHTML (target: [
                    allowMissing: false,
                    alwaysLinkToLastBuild: false,
                    keepAll: true,
                    reportDir: 'doc/',
                    reportFiles: 'index.html',
                    reportName: "Developer Documentation"
                ])
            }
        }
    }
}
