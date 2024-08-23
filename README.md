# Personal Site Infrastructure as Code

As of 2024/08/22:

1) Terraform creates an Azure VM
2) Ansible files are captured by Terraform state
3) Docker is initialized to the VM using Ansible
4) Nginx container is deployed
5) Any changes made to above infrastructure is deployed with `terraform apply`
