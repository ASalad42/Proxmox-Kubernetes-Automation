# K8 Custer Storage

## NFS Shared Storage

- `/config` → persistent storage for app configs
- `/data` → shared data PVC (`arr-data-pvc`), so hard links between Radarr and qBittorrent work properly.
- `local-lvm` and `local` are Proxmox-managed storage pools for VM disks and ISOs — not for shared file access between VMs/Nodes.
- Currently, each VM (master + 2 workers) has its own private virtual disk (32GB) allocated from `local-lvm` on the Proxmox host. These disks are completely isolated block devices.
- Therefore, need a shared filesystem (like NFS) mounted across all three VMs.
  - Add a new shared NFS mount on the Proxmox host at /mnt/media
  - Mount that NFS share inside each VM (master + workers) at /mnt/media
  - Use the NFS CSI driver + NFS StorageClass
  - Each PersistentVolumeClaim (PVC) binds to exactly one PersistentVolume (PV). That PV corresponds to one directory inside NFS server.
    - arr-data-pvc → one shared NFS folder (e.g. /mnt/media/pvc-aaaaa...)
    - If Radarr, qBittorrent, and Jellyfin all use arr-data-pvc then all three are mounting the same directory — the exact same filesystem view.
    - All apps see the same files
    - Hardlinks between qBittorrent and Radarr work
    - Movies downloaded by qBittorrent appear instantly for Radarr and Jellyfin
- Why RWX: It allows Radarr, qBittorrent, Jellyfin, and Prowlarr to all mount /data simultaneously on different nodes.
- Why Retain: Even if pvc is deleted accidentally, the NFS data stays safe.

### Setup

- `sudo apt update && sudo apt install -y nfs-kernel-server`
- `sudo mkdir -p /mnt/media`
- `sudo chown -R 1000:1000 /mnt/media`
- `sudo chmod -R 755 /mnt/media`
- Edit NFS exports file: `sudo nano /etc/exports`
- Add this line: `/mnt/media ip/24(rw,sync,no_subtree_check,no_root_squash)`
- `sudo exportfs -ra`
- `sudo systemctl restart nfs-server`
- `sudo exportfs -v`
- Do this inside each VM (master + worker1 + worker2)
  - `sudo apt update && sudo apt install -y nfs-common`
  - `sudo mkdir -p /mnt/media`
  - `sudo cp /etc/fstab /etc/fstab.bak`
  - `echo "master-ip:/mnt/media  /mnt/media  nfs  defaults  0  0" | sudo tee -a /etc/fstab`
  - `sudo mount -a`
  - `sudo systemctl daemon-reload`
  - `df -h | grep media`
- test with this:
- On worker1 : `echo "hello from worker1" > /mnt/media/test.txt`
- On master: `cat /mnt/media/test.txt`
- `helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts`
- `helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace kube-system --version 4.12.0`
- `helm search repo csi-driver-nfs --versions`
- `kubectl get pods -n kube-system | grep nfs`
- `helm uninstall csi-driver-nfs -n kube-system`
- `kubectl apply -f nfs-media-sc.yml`
- `kubectl get storageclass`
- `kubectl apply -f data-pvc.yml`
- `kubectl apply -f config-pvc.yml`
- `kubectl get pv,pvc -n homelab` - should see new PVs automatically appear with `nfs-media` as their `STORAGECLASS`.
  - PVCs are all Bound meaning dynamic provisioning succeeded
  - PVs were Auto-created and each PVC got its own unique PV (via the NFS CSI driver)

```.sh
┌──────────────────────────────┐
│        Proxmox Host          │
│  (acts as NFS Server)        │
│                              │
│  /mnt/media                  │
│   ├── pvc-12345abcde         │  <-- data for Radarr PVC
│   ├── pvc-67890fghij         │  <-- data for qBittorrent PVC
│   └── pvc-abcdef9999         │  <-- data for Sonarr PVC
└────────────┬─────────────────┘
             │
             │ NFS Export (rw,sync)
             ▼
┌──────────────────────────────┐
│     Kubernetes Cluster       │
│  (Master + 2 Worker Nodes)   │
└────────────┬─────────────────┘
             │
             │ StorageClass → defines backend and uses the NFS CSI driver nfs.csi.k8s.io
             ▼
      ┌────────────────────────────┐
      │  StorageClass: nfs-media   │
      │  provisioner: nfs.csi.k8s.io
      │  server: proxmox-host-ip   │
      │  share: /mnt/media         │
      └──────────┬─────────────────┘
                 │
                 │ PVC Request (e.g. from Radarr)
                 ▼
     ┌─────────────────────────────┐
     │ PersistentVolumeClaim (PVC) │
     │ name: radarr-config-pvc     │
     │ accessModes: RWX            │
     │ storageClassName: nfs-media │
     │ size: 5Gi                   │
     └──────────┬──────────────────┘
                │
                │ dynamically triggers PV creation
                ▼
     ┌──────────────────────────────┐
     │ PersistentVolume (PV)        │
     │ name: nfs-media-pv-12345     │
     │ path: /mnt/media/pvc-12345   │
     │ status: Bound to PVC         │
     └──────────┬───────────────────┘
                │
                │ Mounted via NFS to Pod
                ▼
┌──────────────────────────────────────────┐
│               Pod (Radarr)               │
│------------------------------------------│
│ Mounts:                                  │
│   /config  → radarr-config-pvc           │
│                                          │
│ Reads/Writes files → stored on NFS host  │
└──────────────────────────────────────────┘

```

local storage:

- `kubectl get storageclass`
- `kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml`
- provided by Rancher’s Local Path Provisioner, which is a lightweight dynamic provisioner perfect for homelabs or single-node/multi-node clusters without shared storage (like NFS or Ceph).
- `kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`
