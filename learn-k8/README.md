# CI/CD + Helm deployment for `my-app`

Overview
- A small Helm chart is located at `learn-k8/helm-chart`.
- A Dockerfile and simple `index.html` are in `learn-k8/`.
- A GitHub Actions workflow `.github/workflows/deploy-helm.yml` builds the image, pushes to GCR, fetches GKE credentials, and runs `helm upgrade --install`.

Required GitHub Secrets
- `GCP_PROJECT` — GCP project id (e.g. `satya-k8-poc`).
- `GCP_SA_KEY` — JSON service account key with permissions: Container Engine Admin, Storage Admin (for pushing images) and Service Account User. Store the JSON contents.
- `GKE_CLUSTER` — cluster name (e.g. `my-gke-cluster`).
- `GKE_LOCATION` — cluster zone or region (e.g. `us-central1-a` or `us-central1`).

How it works
1. Push to `main` triggers workflow.
2. Workflow authenticates to GCP using `GCP_SA_KEY` and `GCP_PROJECT`.
3. Builds Docker image from `learn-k8/Dockerfile` and pushes to `us-central1-docker.pkg.dev/$GCP_PROJECT/satya-gcr/aws-cloud-projects-site:$GITHUB_SHA`.
4. Retrieves GKE credentials and runs `helm upgrade --install` into the `learn-master` namespace using the chart in `learn-k8/helm-chart`.

Local testing
- Build the image locally and run Helm upgrade (example):

```bash
docker build -t gcr.io/your-project/my-app:local .
docker push gcr.io/your-project/my-app:local
helm upgrade --install aws-cloud-projects-site learn-k8/helm-chart --namespace learn-master --create-namespace --set image.repository=us-central1-docker.pkg.dev/your-project/satya-gcr/aws-cloud-projects-site --set image.tag=local
```
