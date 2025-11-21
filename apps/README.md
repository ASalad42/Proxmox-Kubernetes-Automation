# Homelab App

```.sh
Browser
  |
  | 1️⃣ GET / or POST /add (form submit)
  v
Frontend Pod
  |
  | 2️⃣ Server-side fetch to backend
  |    (POST /messages or GET /messages)
  v
Backend Service (ClusterIP: backend-service)
  |
  | 3️⃣ Kubernetes routes to one of the Backend Pods
  v
Backend Pod
  |
  | 4️⃣ PostgreSQL client (pg Pool) executes query
  v
PostgreSQL Pod
  |
  | 5️⃣ DB inserts or retrieves messages
  v
Backend Pod
  |
  | 6️⃣ Backend returns JSON of messages
  v
Frontend Pod
  |
  | 7️⃣ Frontend renders messages in HTML
  v
Browser
```

| Tier         | Role                       | Example URL                                                                      |
| ------------ | -------------------------- | -------------------------------------------------------------------------------- |
| **Frontend** | Shows HTML form + messages | [http://frontend.homelab.local/](http://frontend.homelab.local/) |
| **Backend**  | API for DB access          | [http://backend.homelab.local/messages](http://backend.homelab.local/messages)   |
| **Database** | Stores `messages` table    | `postgres.homelab.svc.cluster.local`                                             |

- deploy a simple app which lets users add messages through a web form.
  - Add a new message in the form → frontend posts to backend → backend inserts into PostgreSQL → reloads and displays the updated list.
- `kubectl apply -f postgres-secret.yaml`
- `kubectl apply -f postgres.yml`
- `kubectl apply -f message-job.yaml`
- `kubectl get jobs -n homelab`
- `kubectl logs job/initial-message -n homelab`
- `curl http://backend.homelab.local/messages`
- `kubectl create secret docker-registry NAME --docker-username=user --docker-password=password --docker-email=email -n homelab`
- `kubectl apply -f backend/backend.yaml`
  - `kubectl logs backend-deployment-6dcc886cdf-psg2q -n homelab`
  - `kubectl exec -it deploy/backend-deployment -n homelab -- printenv | grep PG`
  - `kubectl rollout restart deploy/backend-deployment -n homelab`
- `kubectl apply -f frontend/frontend.yml`
  - `kubectl rollout restart deploy/frontend-deployment -n homelab`
- Messages are stored in PostgreSQL (persisted via PVC).
- To test persistence:
  - Open the web ui.
  - Add a few messages.
  - check messages were added to postgres with `kubectl exec -it statefulset/postgres -n homelab -- psql -U admin -d homelabdb -c "SELECT COUNT(*) FROM messages;"`
  - Delete the Postgres pod `kubectl delete pod postgres-0 -n homelab`
  - `kubectl get pods -w`
  - Refresh the web UI — messages still there proving PVC + StatefulSet worked.
  - proof StatefulSet worked = Data in PostgreSQL persists after the pod is deleted and recreated, without any manual backup or reimport.
  - `kubectl delete statefulset postgres -n homelab`
  - `kubectl delete pvc -l app=postgres -n homelab`
- data lives outside the pod postgres-0 lifecycle.
- If the pod is rescheduled to another node, data is reattached from NFS
- can scale with replicas: 3 and each replica will get its own volume
- further test: Delete entire PostgreSQL pod + StatefulSet. but don’t delete the PVCs. The pod (postgres-0) comes back and reattaches the same PVC. When you refresh your Guestbook, the old messages are still there.
  - Each pod in a StatefulSet has a stable name and DNS entry
  - `postgres-0.postgres.homelab.svc.cluster.local`
  - `postgres-1.postgres.homelab.svc.cluster.local` - Even if the pod is deleted or rescheduled to another node, when it’s recreated, it keeps the same identity (postgres-0).
- When StatefulSet is created, Kubernetes automatically generates a unique PVC per replic - use this to check`kubectl get pvc -n homelab`
  - Each PVC name is permanently associated with its pod ordinal index:
  - `postgres-0` → `postgres-data-postgres-0`
  - `postgres-1` → `postgres-data-postgres-1`

| Feature             | Manual PVC (like Radarr)         | `volumeClaimTemplates` (StatefulSet)             |
| ------------------- | -------------------------------- | ------------------------------------------------ |
| Who creates the PVC | manual                           | Kubernetes automatically                         |
| PVC name            | Fixed (`radarr-config-pvc`)      | Dynamic (`postgres-data-postgres-0`, etc.)       |
| Number of PVCs      | 1 (usually shared)               | 1 per replica                                    |
| Best for            | Stateless apps or shared configs | Databases, queues, anything with node-bound data |
| Behavior on restart | PVC stays attached manually      | PVC auto-bound to the same pod ID                |

HPA:

- HPA (HorizontalPodAutoscaler) will automatically scale Guestbook Deployment between 1 and 5 pods depending on CPU usage (when the average CPU usage across pods exceeds 50%).
- check for metrics-server with `kubectl get apiservices` or `kubectl get deployment metrics-server -n kube-system`
- `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`
- `kubectl get pods -n kube-system | grep metrics-server`
- `kubectl apply -f backend-hpa.yaml`
- `kubectl apply -f frontend-hpa.yaml`
- `kubectl describe hpa frontend-hpa -n homelab`
- `kubectl get hpa -n homelab -w`

```.sh
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"},
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP"}
  ]'

```

- `kubectl rollout restart deployment metrics-server -n kube-system`
