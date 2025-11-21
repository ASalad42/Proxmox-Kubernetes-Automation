# Kubernetes Dashboard

<img width="1745" height="890" alt="k8" src="https://github.com/user-attachments/assets/e16bdf43-4a30-494c-9a65-3525d8e99d17" />

The Kubernetess Dashboard is a web-based user interface (UI) that serves as a visual tool to help users manage and monitor their K8s clusters and workloads running on them

- `helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/`

```.sh
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --create-namespace --namespace kubernetes-dashboard \
  --set 'api.containers.args={--disable-csrf-protection=true}' \
  --set kong.proxy.http.enabled=true
```

- `kubectl get deploy -n kubernetes-dashboard kubernetes-dashboard-api -o yaml` check for args
- `kubectl get deploy -n kubernetes-dashboard kubernetes-dashboard-kong -o yaml` check port
- Now need to generate a token to access Kubernetes Dashboard
- create a service account, role and bind the role to the service account, apply it, and get the bearer token for login
  - `kubectl apply -f account.yml`
  - `kubectl -n kubernetes-dashboard create token admin-user`
  - `kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443`

Flow: Browser → Traefik → Kong proxy → Dashboard (web + api + auth)

| Service Name                           | Port | Purpose                                                                                                     |
| -------------------------------------- | ---- | ----------------------------------------------------------------------------------------------------------- |
| `kubernetes-dashboard-web`             | 8000 | The **frontend UI** service — plain HTTP, no auth, not meant for external exposure.                         |
| `kubernetes-dashboard-api`             | 8000 | The internal API backend that the web UI calls.                                                             |
| `kubernetes-dashboard-auth`            | 8000 | Handles token-based authentication and RBAC integration.                                                    |
| `kubernetes-dashboard-kong-proxy`      | 443  | The **secure internal gateway** — routes traffic between web ↔ API ↔ auth using HTTPS and proper headers.   |
| `kubernetes-dashboard-metrics-scraper` | 8000 | Collects cluster metrics for display in the dashboard.                                                      |

- `kubectl apply -f read-only.yml`
- Adjust the RBAC (role-based access control) rules in the read-only-role.yml file if you need to customize the permissions further

| Feature          | **account.yml**                                                         | **read-only.yml**                                                                |
| ---------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **Scope**        | **Cluster-wide** (via `ClusterRole` + `ClusterRoleBinding`)             | **Namespace-limited** (via `Role` + `RoleBinding`)                              |
| **Access level** | Full control — can create, update, delete any resource in any namespace | Read-only — can only view or list specific resource types in a single namespace |
| **RBAC Kind**    | `ClusterRoleBinding` → applies to the *entire cluster*                  | `RoleBinding` → applies only to one namespace                                   |
| **Role used**    | Built-in `cluster-admin` ClusterRole                                    | Custom Role `dashboard-read-only-role`                                          |
| **Use case**     | Administrator or DevOps engineer                                        | Developer or Viewer who should only inspect resources                           |
| **Risk level**   | 🚨 High — can delete the cluster                                        | 🛡️ Safe — cannot change anything                                               |

| Component                            | Role                                                |
| ------------------------------------ | --------------------------------------------------- |
| **ServiceAccount**                   | Identity used by the pod to talk to the API server. |
| **ClusterRole / Role**               | Defines what permissions are allowed.               |
| **ClusterRoleBinding / RoleBinding** | Attaches the role to a ServiceAccount (or user).    |

Ingress:

- `htpasswd -nb ayan supersecret123| openssl base64`
- `kubectl apply -f ingress.yaml`
- `kubectl get secret -n kubernetes-dashboard dashboard-basic-auth`
- `kubectl get middleware -n kubernetes-dashboard`
- `kubectl get ingressroute -n kubernetes-dashboard`
- `kubectl describe node k8s-worker-1 | grep -A5 Allocated`
- `kubectl describe node k8s-worker-2 | grep -A5 Allocated`
- `kubectl top pods -A --sort-by=memory`
- `kubectl top pods -A --sort-by=cpu`
- `kubectl top nodes`
- `kubectl scale deployment homarr jellyfin pihole prowlarr qbittorrent radarr -n homelab --replicas=0`
- `kubectl scale deployment homarr jellyfin pihole prowlarr qbittorrent radarr -n homelab --replicas=1`
- `kubectl scale deployment <deployment-name> --replicas=1`
