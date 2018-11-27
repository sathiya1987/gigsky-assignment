Approach 1:

Step 1: Downlaod and configure  Terraform 

https://www.terraform.io/downloads.html -- find the appropriate package for your system and download it

After downloading Terraform, unzip the package. Terraform runs as a single binary named terraform.

terraform --version or exact path of terraform binary 

Step 2: Ansible Installation

yum install ansible or apt install ansible

Step 3 : AWS CLI 

https://docs.aws.amazon.com/cli/latest/userguide/awscli-install-bundle.html#install-bundle-user  -- Follow this link to configure

Step 4: 

Copy my Gigsky folder on your system.

cd Gigsky/Terraform

Do perform these following commands 

terraform init

terraform plan

terraform apply

It will provision AWS resources and install and configure Nginx on Asg-scaling ec2 instances with ELB .

When hit your A-record of the ELB will you get Nginx 1.html page .

Approach 2 :

Step 1 : Docker Installation

apt install docker-ce

cd Gigsky/docker-setup

docker build -t gigsky:latest .

docker run -p 80:80 --name web gigsky:latest


