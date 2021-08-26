# Tests
## 1. Simulating the loss of one worker node
In this test we will force the leaseholders for all the critical ranges onto a single cockroach node and then terminate the underlying worker node.

### Pre-reqs
* A healthy 3 node cockroach cluster running in Kubernetes
* kubectl access to the Kubernetes cluster
* cockroach sql access to the cockroach cluster

### Steps
1. 
