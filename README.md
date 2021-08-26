# CRDB-statefulset
Deploy CockroachDB on Kubernetes with a statefulset

This repository contains the scripts and manifests to create a 3 node CockroachDB cluster on the major flavours of Kubernetes
* EKS on AWS
* GKE on Google Cloud
* AKS on Azure

Note that although Kubenernetes manifests should be able to be deployed to different flavours of Kubernetes, there are a few subtle changes that need to be made to ensure the Cockroach cluster works correctly and efficiently on each variant so for now I will maintain a different manifest for each Kubernetes variant.


