pipeline {
    
    agent any
    
    environment {
        IPAddressA = '3.36.113.244'
        IPAddressC = '13.125.242.217'
    }
    
    stages {
        
        stage ('BuildA') {
           
            steps {
                
                sshagent(['ASM4_EC2_SSH']) {
                    
                    sh """
                    ssh -o StrictHostKeyChecking=no ubuntu@${IPAddressA} '
                    sudo apt update
                    sudo apt-get install -y default-jdk
                    sudo wget -P /home/ubuntu https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.17/bin/apache-tomcat-10.1.17.tar.gz
                    '
                    """
                }
            }
        }
        
        stage ('BuildC') {
           
            steps {
                
                sshagent(['ASM4_EC2_SSH']) {
                    
                    sh """
                    ssh -o StrictHostKeyChecking=no ubuntu@${IPAddressC} '
                    sudo apt update
                    sudo apt-get install -y default-jdk
                    sudo wget -P /home/ubuntu https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.17/bin/apache-tomcat-10.1.17.tar.gz
                    '
                    """
                }
            }
        }
        
        stage ('DeployA') {

            steps {
                
                sshagent(['ASM4_EC2_SSH']) {
                    
                
                    sh """
                        ssh -o StrictHostKeyChecking=no ubuntu@${IPAddressA} '
                        tar xvzf /home/ubuntu/apache-tomcat-10.1.17.tar.gz
                        sh /home/ubuntu/apache-tomcat-10.1.17/bin/startup.sh
                        '
                        
                    """
                }
            }
            
        }
        
        stage ('DeployC') {
            
            steps {
                
                sshagent(['ASM4_EC2_SSH']) {
                    
                    sh """
                    ssh -o StrictHostKeyChecking=no ubuntu@${IPAddressC} '
                    tar xvzf /home/ubuntu/apache-tomcat-10.1.17.tar.gz
                    sh /home/ubuntu/apache-tomcat-10.1.17/bin/startup.sh
                    '
                    
                """
                }
                
            }
        }
    }
}