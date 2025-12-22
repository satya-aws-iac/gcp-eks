# Kubernetes sample: ConfigMap + Secret + Deployment + Service

Files added:

- `aws-deployment-configmap.yaml` — ConfigMap with application settings
- `aws-deployment-secret.yaml` — Secret (uses `stringData` for easy editing)
- `aws-deployment.yaml` — Deployment that consumes the ConfigMap and Secret
- `aws-service.yaml` — ClusterIP Service for the Deployment

Quick apply (create secret/configmap before the Deployment):

```powershell
# from this directory (Windows PowerShell)
kubectl apply -f aws-deployment-secret.yaml
kubectl apply -f aws-deployment-configmap.yaml
kubectl apply -f aws-deployment.yaml
kubectl apply -f aws-service.yaml
```

Verify resources:

```powershell
kubectl get pods
kubectl get deploy,svc,cm,secret
kubectl describe pod -l app=sample-app
```

Check environment variables inside the pod (example to show values):

```powershell
# find the pod name
$pod = kubectl get pod -l app=sample-app -o jsonpath="{.items[0].metadata.name}"
kubectl exec -it $pod -- /bin/sh -c "env | grep -E 'APP_MESSAGE|LOG_LEVEL|DB_USERNAME|DB_PASSWORD'"

# inspect mounted secret files
kubectl exec -it $pod -- /bin/sh -c "ls -l /etc/credentials && cat /etc/credentials/username && echo '---' && cat /etc/credentials/password"
```

Notes:
- `stringData` in the Secret is convenient for examples; Kubernetes will store it as base64-encoded data.
- Adjust image, replicas, or keys to match your app.
- To delete the resources:

```powershell
kubectl delete -f aws-service.yaml
kubectl delete -f aws-deployment.yaml
kubectl delete -f aws-deployment-configmap.yaml
kubectl delete -f aws-deployment-secret.yaml
```
