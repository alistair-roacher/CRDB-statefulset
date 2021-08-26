#!bash
mkdir certs my-safe-directory

cockroach cert create-ca --certs-dir=certs --ca-key=my-safe-directory/ca.key
cockroach cert create-client root --certs-dir=certs --ca-key=my-safe-directory/ca.key
kubectl create secret generic cockroachdb.client.root -n db --from-file=certs

cockroach cert create-node localhost 127.0.0.1 cockroachdb-public cockroachdb-public.db cockroachdb-public.db.svc.cluster.local *.cockroachdb *.cockroachdb.db *.cockroachdb.db.svc.cluster.local --certs-dir=certs --ca-key=my-safe-directory/ca.key
kubectl create secret generic cockroachdb.node -n db --from-file=certs
