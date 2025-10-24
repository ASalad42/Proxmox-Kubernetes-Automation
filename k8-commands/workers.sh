kubeadm join ip:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>

kubectl get nodes -o wide
kubectl get pods -A
