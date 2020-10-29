pipeline {
    agent any

    stages {
        stage('Deploy') {
          steps {
              ansiblePlaybook(
                  playbook: 'webservers.yml',
                  inventory: 'staging'
              )
            }
        }
    }
}