# Proxmox Kubernetes Cluster

<img width="1641" height="451" alt="image" src="https://github.com/user-attachments/assets/1732ccd6-e1e2-4941-8331-2fc3826c9b9d" />

This project sets up a 3-node Kubernetes cluster on a Proxmox server:

- **Cluster topology:** 1 master (control-plane) node + 2 worker nodes.
- **VM provisioning:** Ubuntu VMs were created on Proxmox using Terraform.
- **Kubernetes setup:** Cluster initialized and configured using Ansible, including:
  - Installing container runtime (containerd)
  - Installing Kubernetes components (kubeadm, kubelet, kubectl)
  - Initializing the master node
  - Deploying Flannel CNI for pod networking
  - Joining worker nodes to the cluster
- **Verification:** All nodes show `Ready` status and system pods are running (`kube-system`, `kube-flannel`).

## ⚙️ Specs

- Host (Proxmox): 8 GB RAM + 2 vCPU reserved.
- Cluster VM OS: Ubuntu Server 24.04 LTS (lightweight, stable, well supported for kubeadm)
- CPU: 1 vCPU each (can overcommit if needed — Proxmox handles it fine)
- RAM: 4 GB each

## 🖥️ Cluster Layout

- 1 Control Plane Node
  - Ubuntu 24.04, kubeadm init runs here.
  - Runs the Kubernetes API server, controller, scheduler, etc.
- 2 Worker Nodes
  - Ubuntu 24.04.
  - Join cluster with the kubeadm join command from the control plane.

## 🛠️ Kubernetes Cluster Setup

### All Nodes

#### Step 1: Update Ubuntu

- `sudo apt update`
  
#### Step 2: Install Dependencies

- `sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release`

#### Step 3: Disable Swap and comment it out in /etc/fstab

- Kubernetes (specifically the kubelet) requires swap to be disabled to ensure consistent and predictable resource management. Once disbaled, this ensures kubelet sees and manages actual RAM usage, not swapped memory on disk.
- `sudo swapoff -a`
- `sudo sed -i '/ swap / s/^/#/' /etc/fstab`

#### Step 4: Load Kernel Modules

- Tells the system to load the kernel modules `overlay` and `br_netfilter` at boot, because Kubernetes’ networking and container runtime underneath it require them.

```.sh
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
```

- `sudo modprobe overlay` - Without `overlay`, containerd can’t manage container images properly
- `sudo modprobe br_netfilter` - Without `br_netfilter`, K8 networking breaks because the pod traffic bypasses the iptables rules used for cluster communication

#### Step 5: Configure Kubernetes IPv4 networking

- `br_netfilter` is what makes net.bridge.bridge-nf-call-iptables and net.bridge.bridge-nf-call-ip6tables available for us to configure.
- `net.ipv4.ip_forward=1` controls whether the Linux kernel forwards packets between network interfaces — required for routing between pods or between nodes in a cluster.

```.sh
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
```

#### Step 6: Reload the change

- `sudo sysctl --system`

#### Step 7 : Install & Configure Containerd Runtime

- `sudo apt install -y containerd`
- `sudo mkdir -p /etc/containerd`
- `containerd config default | sudo tee /etc/containerd/config.toml`
- `sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml`
- `sudo systemctl restart containerd`
- `sudo systemctl enable containerd`

#### Step 8 : Update the package list and install kubelet, kubeadm, and kubectl

- `sudo mkdir -p /etc/apt/keyrings`
- Add Kubernetes Signing Key
  - Since Kubernetes comes from a non-standard repository, download the signing key to ensure the software is authentic.
  - `curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg`
- Add Software Repositories
  - Kubernetes is not included in the default Ubuntu repositories. To add the Kubernetes repository to your list, enter this command on each node:
  - `echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list`
- Install Kubernetes Tools
  - Kubeadm - A tool that initializes a Kubernetes cluster
  - Kubelet - component that actively runs on each node in a cluster to oversee container management. It takes instructions from the master node.
  - Kubectl - CLI tool for managing various cluster components including pods, nodes, and the cluster
  - `sudo apt install -y kubelet kubeadm kubectl`
  - Mark the packages as held back to prevent automatic installation, upgrade, or removal
  - `sudo apt-mark hold kubelet kubeadm kubectl`

### Master Node

#### Initialize Kubernetes Master Node: Initialize the Kubernetes cluster using kubeadm

- `sudo kubeadm init --pod-network-cidr=10.244.0.0/16`

- Towards the end of the output, you will be notified that your cluster was initialized successfully. You will then be required to run the highlighted commands as a regular user. The command for joining the nodes to the cluster will be displayed at the tail end of the output.
- pod network CIDR depends on which CNI you choose — for example, Flannel uses 10.244.0.0/16.
- Create a .kube directory in your home directory
  - `mkdir -p $HOME/.kube`
- copy the cluster's configuration file to the .kube directory.
  - `sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config`
- configure the ownership of the copied configuration file to allow the user to leverage the config file to manage the cluster.
  - `sudo chown $(id -u):$(id -g) $HOME/.kube/config`
- Deploy Pod Network (CNI Plugin) to Cluster - To enable communication between pods across nodes in the cluster, use network plugin because Linux doesn’t do that automatically across multiple machines. That’s what the CNI (Container Network Interface) plugin — like Flannel, Calico, or Cilium.
  - `kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml`

### Worker Nodes

```.sh
kubeadm join ip:6443 --token 123 \
    --discovery-token-ca-cert-hash sha256:12345678
```

- `kubectl get nodes -o wide`
- `kubectl get pods -A`
- `kubectl label node k8s-worker-1 node-role.kubernetes.io/worker=worker`
- `kubectl label node k8s-worker-2 node-role.kubernetes.io/worker=worker`
- verify runtime with `crictl info | grep runtimeType` on any node - should see `"runtimeType": "io.containerd.runc.v2"`

#### Helpful

- `scp -i ~/.ssh/terra ubuntu@ip:/home/ubuntu/.kube/config ~/k8s-master-1-config`
- `export KUBECONFIG=~/.kube/config:~/k8s-master-1-config`
- `kubectl config view --merge --flatten > ~/.kube/config`
- `kubectl config get-contexts`
- `kubectl config use-context kubernetes-admin@kubernetes`
- `sudo apt install -y bash-completion`
- `echo 'source <(kubectl completion bash)' >>~/.bashrc`
- `source ~/.bashrc`

## 🧱 Setup Cluster Infrastructure

- create cloud-init template on proxmox
- `terraform init`
- `terraform validate`
- `terraform fmt -recursive`
- `terraform plan -var-file="dev.tfvars"`
- `terraform apply -var-file="dev.tfvars"`
- `terraform destroy -var-file="dev.tfvars"`
- login using username and password
- `sudo apt update`
- `sudo apt install qemu-guest-agent -y`
- reboot vm and check ip in summary

<img width="726" height="517" alt="image" src="https://github.com/user-attachments/assets/4fb23d2f-007c-4d8c-976d-95543f87cc9c" />
<img width="1424" height="392" alt="image" src="https://github.com/user-attachments/assets/c3d52f8d-7fd5-4355-9ecb-723ec53e1bd9" />

### 🧩 Configured Cluster using Ansible

- Ansible configures master + workers.
- `ansible-playbook -i inventory.ini k8s_prereqs.yml`
- `ansible-playbook -i inventory.ini k8s_master.yml`
- `ansible-playbook -i inventory.ini k8s_workers.yml`
- Scaling new worker VMs:
  - Add to Terraform workers list.
  - Run terraform apply.
  - Run Ansible again.

| Playbook            | Target Nodes            | Key Actions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Result                                                                                                                           |
| ------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **k8s_prereqs.yml** | All (masters + workers) | - Update packages and install dependencies <br> - Disable swap (`swapoff -a` + edit `/etc/fstab`) <br> - Load kernel modules: `overlay`, `br_netfilter` <br> - Apply sysctl params  <br> - Install containerd and configure `SystemdCgroup=true` <br> - Install **kubeadm, kubelet, kubectl** and hold versions | All nodes ready for Kubernetes: container runtime installed, networking kernel params set, swap disabled, kube tools installed and locked |
| **k8s_master.yml**  | Master(s)               | - Initialize cluster: `kubeadm init --pod-network-cidr=10.244.0.0/16` <br> - Configure kubeconfig for ubuntu user <br> - Deploy Flannel CNI: `kubectl apply -f kube-flannel.yml` <br> - Generate `kubeadm join` command and save as Ansible fact                                                                                                                                                                                                                                                                                        | Master node up and running: control-plane ready, Flannel network deployed, join command available for workers                             |
| **k8s_workers.yml** | Worker nodes            | - Fetch `kubeadm join` command from master fact <br> - Execute join command: `kubeadm join ...`                                                                                                                                                                                                                                                                                                                                                                                                                                         | Worker nodes join cluster automatically, cluster ready for workloads                                                                      |

<img width="1052" height="702" alt="image" src="https://github.com/user-attachments/assets/fafdf3cb-b320-47aa-9994-8cf2a17b78d4" />
<img width="1156" height="371" alt="image" src="https://github.com/user-attachments/assets/c7af1b82-3e52-4cd6-9602-2bcc580641fb" />

Understanding the Control Plane:

<img width="848" height="621" alt="image" src="https://github.com/user-attachments/assets/a9dcfa73-feee-4e2a-b24b-a384b002242f" />

How They Work Together: 

1. Run `kubectl create deployment nginx`.
2. `kubectl` sends the request to the `kube-apiserver-k8s-master-1` (Every command (e.g. kubectl get pods) and every internal component talks to the API Server)
3. The `apiserver` writes the desired state to `etcd-k8s-master-1` (key-value database that stores the entire cluster state)
4. The `kube-scheduler-k8s-master-1` notices a new Pod with no node assigned and picks a node.
5. `kube-apiserver` updates etcd with the Pod’s assigned node.
6. The `kube-controller-manager-k8s-master-1` ensures that the number of Pods matches the Deployment spec.
7. The `kubelet` on the selected worker node continuously watches the API server for Pods assigned to its node. When it sees one, it:
    - Pulls the container image
    - Starts the containers via the container runtime containerd
    - Reports back to the API server with the Pod status (Pending → Running)
8. When the `kubelet` creates the Pod, it asks the CNI plugin (Flannel) to set up networking.
     - Result: every Pod in the cluster can talk to every other Pod via a routable Pod IP
12. `CoreDNS` watches the API server for new Services and updates its internal DNS records - **used to resolve the Service name to an IP.**
    - Result: `nginx.default.svc.cluster.local` → 10.96.0.37 (ClusterIP).
    - `kube-proxy` then forwards that traffic to an actual Pod IP via iptables/IPVS.
