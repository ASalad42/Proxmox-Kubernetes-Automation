# Homelab CICD

- GitHub Actions = CI and will build & push versioned images (using Git commit SHA tags).
- Argo CD = CD and will detect the new tags and automatically redeploy frontend and backend pods.

```.sh
Developer → Push code to GitHub
     ↓
GitHub Actions builds Docker images → pushes to Docker Hub
     ↓
GitHub Actions updates Kubernetes manifests (image tags)
     ↓
ArgoCD detects manifest changes → automatically syncs to homelab cluster
     ↓
ArgoCD upgrades pods with new images
```

## ArgoCD

- `helm repo add argo https://argoproj.github.io/argo-helm`
- `helm repo update`
- `kubectl create namespace argocd`
- `helm install argocd argo/argo-cd -n argocd -f values.yml`
- `kubectl get pods -n argocd`
- `kubectl get svc -n argocd`
- `kubectl apply -f ingress.yml`

| Pod / Deployment                | Role                                                                        |
| ------------------------------- | --------------------------------------------------------------------------- |
| `argocd-server`                 | Exposes the web UI and API            |
| `argocd-repo-server`            | Pulls manifests from Git repositories                                       |
| `argocd-application-controller` | **The controller**: watches `Application` CRDs objects and reconciles desired state |
| `argocd-dex-server` (optional)  | Identity provider / login                                                   |
| `argocd-redis`                  | Used internally for caching and queueing                                    |

- In GitHub Actions job, ensure images pushed to docker hub have unique tags
- Dynamically inject current Git SHA into Kubernetes manifest files — keeping deployments tightly tied to source code.
- `ssh-keygen -t rsa -b 4096 -C "argocd-git"`
  - Go to GitHub repo > settings → Deploy keys → Add deploy key > Paste in argocd-git.pub > Check "Allow write access"
  - Add the private key to Argo CD via a mounted secret or go to settings > repo > add private ssh key there
- `kubectl apply -f argocd-repo-creds.yaml`
- `kubectl apply -f argocd-apps.yaml`
- `kubectl get applications -n argocd`
- `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- `kubectl -n argocd get secrets | grep repo`
- `kubectl describe application homelab-apps -n argocd`
- Appication tells ArgoCD to watch repo and look in k8s folder. Deploy those manifests into the default namespace and automatically sync changes.
- Make changes to code > push to github > build image and commit tag to manifest files > argocd sees this and deploys new containers with these new images.
