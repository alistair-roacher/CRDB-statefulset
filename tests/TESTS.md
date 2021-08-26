# Tests
## 1. Simulating the loss of one worker node
In this test we will force the leaseholders for all the critical ranges onto a single cockroach node and then terminate the underlying worker node.

### Pre-reqs
* A healthy 3 node cockroach cluster running in Kubernetes
* kubectl access to the Kubernetes cluster
* cockroach sql access to the cockroach cluster

### Steps
1. Check that all 3 nodes are up and running:

```
> kubectl get pods -l app=cockroachdb
NAME            READY   STATUS    RESTARTS   AGE
cockroachdb-0   1/1     Running   0          28h
cockroachdb-1   1/1     Running   0          25h
cockroachdb-2   1/1     Running   0          28h
> kubectl exec -it cockroachdb-2 -- /cockroach/cockroach node status --certs-dir=/cockroach/cockroach-certs
  id |                       address                        |                     sql_address                      |  build   |            started_at            |            updated_at            |            locality            | is_available | is_live
-----+------------------------------------------------------+------------------------------------------------------+----------+----------------------------------+----------------------------------+--------------------------------+--------------+----------
   1 | cockroachdb-0.cockroachdb.db.svc.cluster.local:26257 | cockroachdb-0.cockroachdb.db.svc.cluster.local:26257 | v20.2.13 | 2021-08-25 11:05:38.012151+00:00 | 2021-08-26 15:09:18.588117+00:00 | region=eu-west-2,az=eu-west-2c | true         | true
   2 | cockroachdb-2.cockroachdb.db.svc.cluster.local:26257 | cockroachdb-2.cockroachdb.db.svc.cluster.local:26257 | v20.2.13 | 2021-08-25 11:04:52.839567+00:00 | 2021-08-26 15:09:18.439651+00:00 | region=eu-west-2,az=eu-west-2a | true         | true
   3 | cockroachdb-1.cockroachdb.db.svc.cluster.local:26257 | cockroachdb-1.cockroachdb.db.svc.cluster.local:26257 | v20.2.13 | 2021-08-25 13:32:22.290826+00:00 | 2021-08-26 15:09:20.874949+00:00 | region=eu-west-2,az=eu-west-2b | true         | true
```

2. Make sure that all the critical ranges are on a single node. In this example let's choose node 1 (cockroach-0) which is deployed in eu-west-2c.
This would be extremely bad practice in production as the loss of the configured availablity zone (or in this case the single node) would mean that every lease in the cluster would have to be recovered by other nodes. Normally leases would be balanced across a number of cluster nodes.  
```
> kubectl exec -it cockroachdb-0 -- /cockroach/cockroach sql --certs-dir=/cockroach/cockroach-certs
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
root@:26257/defaultdb> ALTER RANGE default CONFIGURE ZONE USING lease_preferences = '[[+az=eu-west-2c]]';
CONFIGURE ZONE 1

root@:26257/defaultdb> select range_id, start_pretty, end_pretty, table_name, lease_holder from crdb_internal.ranges order by range_id limit 15;
  range_id |         start_pretty          |                                end_pretty                                |  table_name  | lease_holder
-----------+-------------------------------+--------------------------------------------------------------------------+--------------+---------------
         1 | /Min                          | /System/NodeLiveness                                                     |              |            1
         2 | /System/NodeLiveness          | /System/NodeLivenessMax                                                  |              |            1
         3 | /System/NodeLivenessMax       | /System/tsd                                                              |              |            1
         4 | /System/tsd                   | /System/tsd/cr.node.sys.host.net.send.packets/3/10s/2021-08-26T11:00:00Z |              |            1
         5 | /System/"tse"                 | /Table/SystemConfigSpan/Start                                            |              |            1
         6 | /Table/SystemConfigSpan/Start | /Table/11                                                                |              |            1
         7 | /Table/11                     | /Table/12                                                                | lease        |            1
         8 | /Table/12                     | /Table/13                                                                | eventlog     |            1
         9 | /Table/13                     | /Table/14                                                                | rangelog     |            1
        10 | /Table/14                     | /Table/15                                                                | ui           |            1
        11 | /Table/15                     | /Table/16                                                                | jobs         |            1
        12 | /Table/16                     | /Table/17                                                                |              |            1
        13 | /Table/17                     | /Table/18                                                                |              |            1
        14 | /Table/18                     | /Table/19                                                                |              |            1
        15 | /Table/19                     | /Table/20                                                                | web_sessions |            1
(15 rows)
```
You may need to run this last statement a few times before all the leases have transferred to the desired node.
Note that a number of key tables in the system database (descriptor, namespace, settings, tenants, users and zones) are all stored in range 6.

3. Test that connections can be made successfully to the cluster using the conntest user.
```
> kubectl exec -it cockroachdb-2 -- /cockroach/cockroach sql --url 'postgres://conntest:conntest@localhost:26257/defaultdb?sslmode=require' -e 'select user,now()'
  current_user |               now
---------------+-----------------------------------
  conntest     | 2021-08-26 15:15:42.507411+00:00
(1 row)
```

4. Set up connection tests on each pod. 
```
# Running this script copies the conntest script to each node and runs it in the background using nohup
> ./start_conntest
Unable to use a TTY - input is not a terminal or the right kind of file
Unable to use a TTY - input is not a terminal or the right kind of file
Unable to use a TTY - input is not a terminal or the right kind of file

# We can safely ignore the TTY messages above
# Let's check that the output is as expected
> for node in 0 1 2
do
  echo "cockroachdb-${node}"
  echo =============
  kubectl exec -it cockroachdb-${node} -- tail -3 cockroach-data/conntest/ct.log  
  echo 
done

cockroachdb-0
=============
Thu Aug 26 15:53:43 UTC 2021
now
2021-08-26 15:53:43.474912+00:00

cockroachdb-1
=============
Thu Aug 26 15:53:44 UTC 2021
now
2021-08-26 15:53:44.573611+00:00

cockroachdb-2
=============
Thu Aug 26 15:53:45 UTC 2021
now
2021-08-26 15:53:45.910669+00:00
```
If the timestamps shown for all 3 nodes are within the last few seconds then we have everything in place to montitor connections locally on each pod.

5. Identify the underlying worker node and terminate it. Remember that we chose to move all the leases to the cockroach node running in pod cockroachdb-0 so we are aiming to terminate the node running this pod. We can discover the name of that node using the following:
```
> kubectl get pods -l app=cockroachdb -o=custom-columns='NAME:metadata.name,NODE:spec.nodeName'
NAME            NODE
cockroachdb-0   ip-192-168-183-195.eu-west-2.compute.internal
cockroachdb-1   ip-192-168-138-150.eu-west-2.compute.internal
cockroachdb-2   ip-192-168-108-82.eu-west-2.compute.internal
```

We also need to make sure that the anti-affinity rules are working and all of the nodes are on different worker nodes. In this configuration, CockroachDB can survive the loss of one node, but not 2 (as this would be a loss of quorum).

To terminate the worker node, there are 2 options:
* Locate the resource in the Cloud console and click on Terminate
* Use the appropriate cloud cli command


6. Observe the worker nodes and cockroach pods. It may take several seconds for the node to terminate and several minutes for Kubernetes to start a new worker node and schedule a new cockroach pod to replace the ones that were lost.

7. Retrieve the connection logs from the pods. As we wrote the logs to the /cockroach/cockroach-data mountpoint, they will be available on all 3 nodes (even the one that was killed) as the recheduled pod will attach to the same Kubernetes volume as before.
```
./get_logs
tar: Removing leading `/' from member names
tar: Removing leading `/' from member names
tar: Removing leading `/' from member names
```
The messages can be safely ignored.

