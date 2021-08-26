# Instructions for deploying CockroachDB on EKS
## Steps
* Ensure that the AWS command line utility V2 is installed - see https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
* Configure the aws command so that you can connect to and control resources in your AWS account - https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
* Ensure that eksctl is installed - this will issue the required aws eks commands under the covers so requires no additional configuration - https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html
* Ensure that your AWS account has the appropriate permissions to create EKS cluster and EC2 worker nodes - 
