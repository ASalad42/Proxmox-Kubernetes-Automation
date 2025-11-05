# Setup Cluster Monitroing

<img width="1901" height="873" alt="k8dash" src="https://github.com/user-attachments/assets/755113ad-9c43-4aff-8d8c-8356a09284ac" />


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

<img width="1902" height="841" alt="image" src="https://github.com/user-attachments/assets/109f7596-169e-4e56-8327-e00039b553ef" />


Alert Manager:

- Turn off vm to test node down rule
- `kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090`
- `http://localhost:9090/rules` check for NodeDown rule under node.rules
- `kubectl get prometheusrules -n monitoring`
- `kubectl get prometheus -n monitoring -o yaml | grep -A5 ruleSelector`
  - rule must carry the same label(s) under metadata.labels.
- check alert manager config was injected in from secret with `kubectl exec -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager-0 -c alertmanager -- sh -c "cat /etc/alertmanager/config_out/alertmanager.env.yaml"`
- query `up{job="node-exporter"}`

<img width="1872" height="807" alt="image" src="https://github.com/user-attachments/assets/ff3198d5-38be-4681-968c-90c78fd2d90e" />
