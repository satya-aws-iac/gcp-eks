# Postgres DB sample manifests

Files added:

- `aws-db-configmap.yaml` — non-sensitive DB settings (e.g. `POSTGRES_DB`)
- `aws-db-secret.yaml` — credentials (`POSTGRES_USER`, `POSTGRES_PASSWORD`) using `stringData`
- `aws-db-pvc.yaml` — PVC for persistent storage (1Gi example)
- `aws-db-deployment.yaml` — Deployment using `postgres:15-alpine`, mounts PVC and consumes ConfigMap/Secret
- `aws-db-service.yaml` — ClusterIP Service on port 5432

Apply order (recommended):

```powershell
# from this directory
kubectl apply -f aws-db-secret.yaml
kubectl apply -f aws-db-configmap.yaml
kubectl apply -f aws-db-pvc.yaml
kubectl apply -f aws-db-deployment.yaml
kubectl apply -f aws-db-service.yaml
```

Verify the DB is running:

```powershell
kubectl get pvc
kubectl get pods -l app=postgres
kubectl get svc postgres-service
kubectl logs -l app=postgres
kubectl describe pod -l app=postgres
```

Connect to the DB from another pod (example using `psql` client):

```powershell
# create a quick client pod (if you don't have one) and run psql
kubectl run -i --rm psql-client --image=postgres:15-alpine --restart=Never --env="PGPASSWORD=S3cureP@ssw0rd" --command -- psql -h postgres-service -U dbuser -d sampledb
```

Notes & best practices:
- The sample uses `stringData` for easy editing; Kubernetes stores the Secret base64-encoded. For production, use sealed secrets or an external secret manager.
- The PVC requests `1Gi` storage — change as required and set `storageClassName` if your cluster needs a specific storage class.
- Running databases in Kubernetes benefits from StatefulSets and proper storage tuning; this Deployment is a simple example for development and testing.
- Consider backups and readiness/liveness probes for production readiness.

To delete resources:

```powershell
kubectl delete -f aws-db-service.yaml
kubectl delete -f aws-db-deployment.yaml
kubectl delete -f aws-db-pvc.yaml
kubectl delete -f aws-db-configmap.yaml
kubectl delete -f aws-db-secret.yaml
```
