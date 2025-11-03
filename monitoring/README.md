# Setup Cluster Monitroing

- `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`
- `helm repo add grafana https://grafana.github.io/helm-charts`
- `helm repo update`
- `kubectl create namespace monitoring`
- `kubectl apply -f alertmanager-config-secret.yaml`

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
- `kubectl apply -f node-down-alert.yaml`
- `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`
- `kubectl apply -f grafana-ingress.yaml`
- `kubectl get ingress -n monitoring`
- access at `http://grafana.homelab.local`
- Username: admin and `kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d`
- import 1860 and 15661

Alert Manager:

- Turn off vm to test node down rule
- `kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090`
- `http://localhost:9090/rules` check for NodeDown rule under node.rules
- `kubectl get prometheusrules -n monitoring`
- `kubectl get prometheus -n monitoring -o yaml | grep -A5 ruleSelector`
  - rule must carry the same label(s) under metadata.labels.
- check alert manager config was injected in from secret with `kubectl exec -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager-0 -c alertmanager -- sh -c "cat /etc/alertmanager/config_out/alertmanager.env.yaml"`
- query `up{job="node-exporter"}`
