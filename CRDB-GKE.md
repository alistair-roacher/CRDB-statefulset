# Instructions for deploying CockroachDB on EKS
## Setup Pre-reqs
* Ensure that the AWS command line utility V2 is installed - see https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
* Configure the aws command so that you can connect to and control resources in your AWS account - https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html
* Ensure that eksctl is installed - this will issue the required aws eks commands under the covers so requires no additional configuration - https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html
* Ensure that your AWS account has the appropriate permissions to create an EKS cluster and EC2 worker nodes

The file install-eks.txt has all the necessary detail to complete the above tasks. You should now be ready to create an EKS cluster with eksctl:
```
> eksctl create cluster --name cockroachdb --nodegroup-name standard-workers --node-type m5.xlarge --nodes 3 --nodes-min 1 --nodes-max 4 --node-ami auto
```

You may find that the eksctl command to create the cluster fails because of a lack of resources in the current region (EKS is quite hungry for certain resources - particularly VPCs and IP addresses) so you may need to request certain resource limits to be raised for your configured region, or you can simply use another region instead. 

Attempting to create a cluster after a previous failed attempt can fail with the following error: 
```
2021-08-26 12:45:17 [✖]  creating CloudFormation stack "eksctl-cockroachdb-cluster": AlreadyExistsException: Stack [eksctl-cockroachdb-cluster] already exists
        status code: 400, request id: 580913e0-0e63-456e-b190-37c9856eed2b
```
This happens because the previous failed attempt has not tidied up the CloudFormation stack. You can do this manually with the eksctl delete command:
```
> eksctl delete cluster cockroachdb
2021-08-26 12:46:17 [ℹ]  eksctl version 0.56.0-rc.0
2021-08-26 12:46:17 [ℹ]  using region eu-west-2
2021-08-26 12:46:17 [ℹ]  deleting EKS cluster "cockroachdb"
2021-08-26 12:46:18 [ℹ]  1 task: { delete cluster control plane "cockroachdb" [async] }
2021-08-26 12:46:18 [ℹ]  will delete stack "eksctl-cockroachdb-cluster"
2021-08-26 12:46:18 [✔]  all cluster resources were deleted
```
Note that the deletion of the CLoudFormation stack can take several minutes to complete.

You should now have an EKS cluster created. You can check this with either aws or eksctl:
```
> aws eks list-clusters
{
    "clusters": [
        "cockroachdb",
    ]
}
> eksctl get clusters
2021-08-26 12:28:00 [ℹ]  eksctl version 0.56.0-rc.0
2021-08-26 12:28:00 [ℹ]  using region eu-west-2
NAME                    REGION          EKSCTL CREATED
cockroachdb             eu-west-2       True
```
Note that you might see other clusters created by yourself or other users in your organisation.  

You can't do a lot with your cluster until kubectl is connectly configured. Fortunately there is an aws eks command to add the necessary details to the Kubernetes config file (which by default is $HOME/.kube/config): 
```
> 
```
You can test that this has worked using:
```
> kubectl context get-contexts
CURRENT   NAME                                               CLUSTER                                             AUTHINFO                                            NAMESPACE
*         gke_cockroach-alistair                             gke_cockroach-alistair_europe-west2-c_cockroachdb   gke_cockroach-alistair_europe-west2-c_cockroachdb
> kubectl get all
```
As you can see the context name is not very user friendly - plus it has no value for the namespace which means that if we perform any kubectl operations on namespaces other than default then will will have to specify the namespace on every command. Let's create a new namespace called db for our cockroach cluster: 

```
kubectl create namespace db
namespace/db created
```
And modify the K8s config file ($HOME/.kube/config). Change this:
```
contexts:
- context:
    cluster: gke_cockroach-alistair_europe-west2-c_cockroachdb
    user: gke_cockroach-alistair_europe-west2-c_cockroachdb
  name: gke_cockroach-alistair_europe-west2-c_cockroachdb
current-context: gke_cockroach-alistair_europe-west2-c_cockroachdbgke-db
```
To this:
```
- context:
    cluster: gke_cockroach-alistair_europe-west2-c_cockroachdb
    namespace: db
    user: gke_cockroach-alistair_europe-west2-c_cockroachdb
  name: gke-db
- context:
    cluster: gke_cockroach-alistair_europe-west2-c_cockroachdb
    namespace: default
    user: gke_cockroach-alistair_europe-west2-c_cockroachdb
  name: gke-default
current-context: gke-db
```

When using the context gke-db your kubectl commands will now operate on the db namespace rather than on the default namespace.
Ensure that this is the current context:
```
> kubectl config use-context gke-db
Switched to context "gke-db".
> kubectl get all
No resources found in db namespace.
```

Before creating the Kubernetes objects to deploy our cluster we must first create the certificates - use the create-certs.sh script to achieve this. This creates a number of certs using the cockroach certs command and loads them into a couple of Kubernetes secrets that can be loaded by the cockroach statefulset.

To deploy the cockroachdb statefulset (and other supporting objects), run the following:
```
> kubectl apply -f gke_statefulset.yaml
> kubectl get all
> kubectl get endpoints cockroachdb-public
```
Once the 3 pods have reached a status of "Running" you can initialise the cockroach cluster:  
```
> kubectl get pods
NAME            READY   STATUS    RESTARTS   AGE
cockroachdb-0   0/1     Running   0           2m
cockroachdb-1   0/1     Running   0           2m
cockroachdb-2   0/1     Running   0           2m
> kubectl exec -it cockroachdb-0 -- /cockroach/cockroach init --certs-dir=/cockroach/cockroach-certs

```
You can see above that all of the pods were showing 0/1 in the READY column. This shows that there is a single container in each pod and that it is not in ready state - i.e. not able to accept traffic. This is because until the cluster is initialised, no connections can be accepted by any node in the cluster. 

Note: if you do see one pod showing as 1/1 before initialising the cluster then you have created a one node cluster by mistake. 

With all pods in this non-ready state, there will be no endpoints servicing the cockroachdb-public service (as shown above), but having successfully initialise the cluster we should now see all 3 pods as ready and endpoints for the cockroachdb-public service:
```
> kubectl get pods
NAME            READY   STATUS    RESTARTS   AGE
cockroachdb-0   1/1     Running   0           5m
cockroachdb-1   1/1     Running   0           5m
cockroachdb-2   1/1     Running   0           5m
> kubectl get endpoints cockroachdb-public
NAME                 ENDPOINTS                                                                     AGE
cockroachdb-public   192.168.101.3:26257,192.168.130.109:26257,192.168.164.110:26257 + 3 more...    5m
```
The reason that it says "3 more" is that there are 2 endpoints per pod - one listening on 26257 for inter-node and SQL traffic, and one on 8080 for the DB Console and REST API. 

You should now be able to connect to the cluster and issue SQL statements:
```
> kubectl exec -it cockroachdb-2 -- /cockroach/cockroach sql --certs-dir=/cockroach/cockroach-certs
#
# Welcome to the CockroachDB SQL shell.
# All statements must be terminated by a semicolon.
# To exit, type: \q.
#
# Server version: CockroachDB CCL v20.2.13 (x86_64-unknown-linux-gnu, built 2021/07/12 11:36:21, go1.13.14) (same version as client)
# Cluster ID: 191654f4-2b13-405d-a980-cbd75a12bf17
#
# Enter \? for a brief introduction.
#
root@:26257/defaultdb> select node_id,address,build_tag,is_live from crdb_internal.gossip_nodes;
  node_id |                       address                        | build_tag | is_live
----------+------------------------------------------------------+-----------+----------
        1 | cockroachdb-0.cockroachdb.db.svc.cluster.local:26257 | v20.2.13  |  true
        2 | cockroachdb-2.cockroachdb.db.svc.cluster.local:26257 | v20.2.13  |  true
        3 | cockroachdb-1.cockroachdb.db.svc.cluster.local:26257 | v20.2.13  |  true
(3 rows)

Time: 1ms total (execution 1ms / network 0ms)

root@:26257/defaultdb>
```
