# CRDB-statefulset
Deploy CockroachDB on Kubernetes with a statefulset

This repository contains the scripts and manifests to create a 3 node CockroachDB cluster on the major flavours of Kubernetes
* EKS on AWS
* GKE on Google Cloud
* AKS on Azure

Note that although Kubenernetes manifests should be able to be deployed to different flavours of Kubernetes, there are a few subtle changes that need to be made to ensure the Cockroach cluster works correctly and efficiently on each variant so for now I will maintain a different manifest for each Kubernetes variant.

# Pre-reqs
You will need the ability to create resources in the appropriate public cloud. 
You will also need to install the following on the machine or server that you will use to deploy and manage your K8s clusters and resources:
* kubectl
* helm
* docker (optional)
* eksctl (Cluster creation utility - EKS only)
* aws (AWS CLI - EKS only)
* gcloud (Google Cloud CLI - GKE only)
* az (Azure CLI - AKS only)

# Basic Steps
* Create a managed Kubernetes cluster and attach a minimum of 3 worker nodes
* Ensure that you have kubectl access to your cluster from the machine you are going to use for deployment
* Set up a K8s storage class to provision the appropriate class of storage 
* Prepare and deploy the Kubernetes manifests to create the Cockroach Cluster and supporting objects
* Perform some basic connectivity and resilience testing 
