# Instructions for deploying CockroachDB on EKS
## Setup Pre-reqs

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
