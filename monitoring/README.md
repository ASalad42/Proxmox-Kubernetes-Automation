# Setup Cluster Monitroing

- `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`
- `helm repo add grafana https://grafana.github.io/helm-charts`
- `helm repo update`
- `kubectl create namespace monitoring`

```.bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yml
```

```.bash
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yml

```

- `kubectl get pods -n monitoring -o wide`
- `kubectl get pvc -A`
- `kubectl apply -f pve.yml`
- `kubectl apply -f deploy.yml`
- Username: admin and `kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d`
