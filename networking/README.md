# Networking

## 🖥️ Proxmox Host Network

- Setup Gateway and Proxmox Host IP during installation - ensured on the same lan as wifi.
- `nano /etc/network/interfaces`
- `systemctl restart networking`
- **Virtual Machine Layer**: vmbr0 connects host Ethernet (ens18 pysical NIC) to VMs. Proxmox host’s physical Ethernet port, connected to LAN.
  - This bridge connects all VMs to the same LAN as the Proxmox host.
  - Each VM connects to vmbr0 with its own static IP, so all are on the same network — they can talk directly to each other without routing.
  - VM interfaces: eth0 inside VMs is bridged via vmbr0
  - eth0 inside each VM → virtual NIC attached to vmbr0.
- **Kubernetes Node Layer**: cni0 is the bridge inside the node connecting all the Pod virtual NICs (each Pod’s eth0).
- laptop → router → ens18 (Physical NIC to LAN) → vmbr0 (Proxmox bridge) → VM eth0 bridged via vmbr0 → pod eth0 via Kubernetes CNI Bridge cni0 and flannel

```.sh
Laptop (Wi-Fi, 192.xx.x.xxx)
       |
       |   (Wi-Fi → Router)
       |
Router / Gateway (192.xx.x.x)
       |
       |   (LAN Ethernet)
       |
Proxmox Host (host-ip, ens18)
       |
       |---- vmbr0 (Proxmox Linux bridge connecting the physical NIC (ens18) to all VMs’ virtual NICs (eth0).)
       |
       |---- Master VM (master-ip, eth0)
       |         - Kubernetes pods / services
       |
       |---- Worker1 VM (worker1-ip, eth0)
       |         - Kubernetes pods / services
       |
       |---- Worker2 VM (worker2-ip, eth0)
                 - Kubernetes pods / services

```

## 🖥️ Cluster Networking

```.sh

Prometheus Pod (10.244.2.8, k8s-worker-2)
   │
   ├─ DNS query → CoreDNS
   │     • CoreDNS runs in kube-system and resolves all cluster service names.
   │     • Resolves pve-exporter.monitoring.svc.cluster.local → 10.103.189.90 (ClusterIP)
   │     • kube-apiserver picks a free IP from --service-cluster-ip-range
   │
   ├─ Prometheus Pod makes HTTP request to → http://10.103.189.90:9221/metrics
   │     • Sent from Prometheus to the pve-exporter service endpoint.
   │
   ├─ Routed via ClusterIP → pve-exporter Pod (10.244.2.9:9221)
   │     • kube-proxy handles ClusterIP to Pod IP - Detects traffic to pve-exporter service
   │     • uses kube-proxy’s iptables rule to map Destination: 10.103.189.90:9221 → 10.244.2.9:9221
   │     • That’s Destination NAT — it changes where the packet is going i.e it changes destination to 10.244.2.9:9221
   │
   ├─ Flannel (CNI) routes the packet to the target Pod
   │     • Handles pod-to-pod networking across nodes
   │     • Ensures Prometheus Pod can reach pve-exporter Pod IP 10.244.2.9
   │     • There is one Flannel Pod on each node. Each node gets a subnet for its Pods. The node’s Flannel Pod knows the IP ranges of all nodes.
   │
   ├─ Exporter queries → https://host-ip:8006 (Proxmox API)
   │     • The exporter connects to the Proxmox host’s API endpoint.
   │
   └─ Returns metrics → Prometheus scrapes → Grafana dashboards visualize
```

- `sudo iptables -t nat -L KUBE-SERVICES -n --line-numbers`
- `sudo iptables -t nat -L KUBE-SVC-7GIQ3ANJH7YSMEW2 -n -v`
- `sudo iptables -t nat -L KUBE-SEP-YOGQYWYURPGSJGLJ -n -v`
- `ip addr show flannel.1`
- `ip route`

### Flannel Networking

| Level        | CIDR            | Owner           | Purpose             |
| ------------ | --------------- | --------------- | ------------------- |
| Cluster-wide | `10.244.0.0/16` | Flannel network | All pods            |
| Per-node     | `10.244.x.0/24` | Each node       | Pod subnet per node |

- When K8s was installed (via kubeadm) - told it what pod network CIDR to use i.e `kubeadm init --pod-network-cidr=10.244.0.0/16`
- That /16 means all Pods across cluster will use IPs in the range 10.244.0.0 → 10.244.255.255
- Flannel takes that /16 range and splits it into smaller subnets, one per node
- Backend Type = vxlan - VXLAN (Virtual Extensible LAN)

| Node       | Flannel Subnet |
|------------|----------------|
| Master     | 10.244.0.0/24  |
| Worker1    | 10.244.1.0/24  |
| Worker2    | 10.244.2.0/24  |

- When a Pod is created on Worker2, the kubelet asks Flannel for an available IP from the Worker2 subnet (10.244.2.0/24).
- Flannel allocates the next available IP, e.g., 10.244.2.9, and stores it in its network state.
- This IP becomes the Pod’s virtual eth0 IP and is reachable cluster-wide through Flannel’s VXLAN overlay.

```.sh

Pod eth0 (10.244.1.5, Worker1)
   │
   ▼
cni0 bridge (Worker1) - All Pod eth0s on the node are connected to cni0 = virtual bridge connecting all local Pods on the node
   └─ The Pod sends a packet to 10.244.2.9 → hits the node’s CNI bridge
   │
   ▼
flannel.1 interface (Worker1)
   └─ Flannel intercepts and encapsulates the packet destined for remote pod in VXLAN (UDP)
   └─ Adds a VXLAN header with destination node IP (worker2-ip)
   │
   ▼
Node eth0 (Worker1) → sends packet like this: eth0 (VM1) → vmbr0 (Proxmox bridge) → eth0 (VM2)
   │
   ▼
Node eth0 (Worker2) receives the VXLAN packet
   │
   ▼
flannel.1 decapsulates VXLAN → extracts inner Pod packet
   │
   ▼
cni0 bridge (Worker2)
   └─ Delivers packet to Pod 10.244.2.9
   │
   ▼
Pod eth0 (10.244.2.9, Worker2)
```

### DHCP

- Log into Router admin settings → Advanced Settings → DHCP → Reserved IPs
- Find VM (or manually enter its MAC address, from Proxmox → VM → Hardware → Network Device).
- Assign static IP permanently to that MAC

## Ingress

1. User → types `https://radarr.homelab.local`
2. DNS (or /etc/hosts) → resolves to the Traefik LoadBalancer Service
3. Traefik → reads Ingress and routes to radarr Service
4. cert-manager + ClusterIssuer → automatically request and renew Let’s Encrypt SSL certs for domain
5. Radarr Pod → responds with the web UI via HTTPS

```.sh
👩‍💻 User Browser
    │
    │ 1️⃣  http://homarr.homelab.local
    ▼
🧩 Windows hosts file
    • Entry: ip homarr.homelab.local
    │
    │ 2️⃣ DNS resolution happens locally → Browser connects to ip
    ▼
🌐 Traefik LoadBalancer Service (MetalLB)
    • MetalLB has assigned external IP
    • Service type: LoadBalancer → forwards port 80 → Traefik Pod(s)
    │
    │ 3️⃣ Packet hits Node’s kube-proxy → forwarded to a Traefik Pod
    ▼
🚦 Traefik Ingress Controller (Pod in kube-system)
    • Watches all Ingress objects in the cluster
    • Finds matching rule:
          host: homarr.homelab.local
            → backend: Service homarr (port 7575)
    │
    │ 4️⃣ Traefik proxies HTTP request → cluster-internal network
    ▼
🔹 homarr Service (ClusterIP)
    • Type: ClusterIP → virtual IP inside cluster (e.g. 10.107.171.153)
    • Selects Pods with label app=homarr
    │
    │ 5️⃣ kube-proxy routes to one of the matching Homarr Pods
    ▼
📦 homarr Pod
    • Container port 7575 is open
    • App serves the web UI
    │
    │ 6️⃣ Response travels back the same route:
    ▼
    homarr Pod → Service → Traefik → Node → Browser
    (HTTP response content returned to user)
```

| Component     | Purpose                  |
| ------------- | ------------------------ |
| Traefik       | Ingress Controller       |
| MetalLB       | Bare-metal LoadBalancer  |
| cert-manager  | Certificate automation   |
| ClusterIssuer | Let’s Encrypt            |
| Ingress       | App HTTPS routing        |

### 🧩 MetalLB

- Provides external IPs for Services of type LoadBalancer on bare metal.
- `helm repo add metallb https://metallb.github.io/metallb`
- `helm repo update`
- `helm install metallb metallb/metallb --namespace metallb-system --create-namespace`
- `kubectl apply -f metallb-config.yaml`
- In a cloud cluster like EKS, the cloud provider would assign a public IP. But on bare metal (like Proxmox homelab), Kubernetes doesn’t have that mechanism by default. That’s where MetalLB comes in — it acts as the “cloud load balancer” for bare metal clusters. **It watches for Service objects of type LoadBalancer.**
- When MetalLB sees Traefik’s Service, it:
  - Picks an IP from the pool you defined in metallb-config.yaml
  - Assigns that IP to the Traefik Service
  - Announces that IP to LAN using ARP (Layer 2 mode)

### 🌐 Traefik Ingress

- `helm repo add traefik https://traefik.github.io/charts`
- `helm repo update`
- `helm install traefik traefik/traefik -f traefik-values.yaml -n kube-system`
- `helm upgrade traefik traefik/traefik -f traefik-values.yaml -n kube-system`
- `kubectl get svc -n kube-system traefik`
- `helm get values traefik -n kube-system`
- `service/traefik LoadBalancer   10.110.59.193   ip   80:30093/TCP,443:32342/TCP     16m`
- access web ui at `http://traefik.homelab.local`
  - `htpasswd -nb ayan password | openssl base64` - paste the encoded string under data.users. use `sudo apt-get install apache2-utils` to install htpassword
  - `kubectl apply -f middleware-secret.yaml`
  - `kubectl apply -f middleware-auth.yaml` - check crd/api with `kubectl get crd | grep traefik` and `kubectl api-resources | grep traefik`
  - Attach Middleware to the Dashboard IngressRoute in traefik-values.yaml
  - `helm upgrade traefik traefik/traefik -f traefik-values.yaml -n kube-system`
  - very with `kubectl get ingressroute -n kube-system` and `kubectl describe ingressroute traefik-dashboard -n kube-system`
  - `kubectl get crds | grep traefik`
  - Access within login prompt
- `kubectl describe svc traefik -n kube-system` shows that MetalLB assigned this IP from the homelab-pool defined in metallb-config.yaml to the Traefik service.
  - MetalLB’s controller successfully allocated the IP
  - MetalLB’s speaker is broadcasting ARP announcements from k8s-worker-2, meaning any device on local network that requests ip will be routed to that node.

Create an Ingress for app (Radarr example)

- radarr.homelab.local → points to traefik (via /etc/hosts)
- ip   radarr.homelab.local qbittorrent.homelab.local jellyfin.homelab.local
- `kubectl apply -f radarr.yml`
- `kubectl get ingress -n homelab`
- `kubectl describe certificate radarr-tls -n homelab`
- `kubectl get certificate -n homelab`
- for quick test use `kubectl port-forward -n homelab svc/radarr 7878:7878`
- Verification Flow
  - Ingress created → Traefik picks it up
  - User → visits `http://radarr.homelab.local`
  - can also access at `http://ip/radarr` once base url is changed in ui

### Pi-hole

When TV or phone tries to open `http://radarr.homelab.local`, here’s what happens:

- Device asks router:
  - “What’s the IP for radarr.homelab.local?”
- Router checks its DNS forwarding rule:
  - It sees that .homelab.local should be handled by Pi-hole (ip).
- Router forwards the DNS query → Pi-hole.
- Pi-hole answers:
  - “radarr.homelab.local = ip” (Traefik’s IP)
- The device then connects directly to Traefik (ip), which routes the request to Radarr service inside Kubernetes.
- Result → Radarr UI loads!
- `kubectl apply -f pihole-secret.yaml`
- `kubectl get secret pihole-secret -n homelab`
- `kubectl apply -f pihole.yml`
- `http://ip/admin`

### 🔐 Using cert-manager with a Let’s Encrypt ClusterIssuer

- cert-manager → handles the communication with Let’s Encrypt.
- Let’s Encrypt → validates domain and issues the TLS certificate.
- cert-manager → stores that certificate inside cluster as a Kubernetes Secret (e.g., radarr-tls).
- Traefik → uses that Secret to serve HTTPS for Ingress (e.g., `https://radarr.homelab.local`).
- `helm repo add jetstack https://charts.jetstack.io`
- `helm repo update`

```.sh
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

- before CRDs for certificates exits there will be an error like this "error: the server doesn't have a resource type "certificate"
- `kubectl get pods -n cert-manager`
- `kubectl apply -f cluster-issuer.yaml`
- created secret `cloudflare-api-token-secret` and cert manager creates secrets `letsencrypt-staging-secret` and `homarr-tls-secret`
