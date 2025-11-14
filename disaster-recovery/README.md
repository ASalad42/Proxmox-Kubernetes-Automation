
# Disaster Recovery

| Component                   | Backup Method          | Restores                              |
| --------------------------- | ---------------------- | --------------------------------------- |
| **Cluster State**           | Velero                 | All K8s objects, apps, Traefik, MetalLB |
| **Node OS / kubeadm certs** | Proxmox VM backups     | Node identity, kubelet, OS              |
| **Persistent Volumes**      | NFS backup             | App data                                |

## Proxmox VM Backups

```.sh
Proxmox Backup Job (snapshot mode)
 ├── VM1: Kubernetes master   ← Snapshotted at the same time
 ├── VM2: Kubernetes worker   ← Snapshotted at the same time
 └── VM3: Kubernetes worker   ← Snapshotted at the same time
```

In Proxmox UI:

- Go to Datacenter → Backup
- Create a new backup job:
  - Nodes: Proxmox node
  - Storage: local
  - Selection: select all 3 Kubernetes VMs
  - Mode: snapshot (important!)
  - Schedule: daily or weekly
  - Go to VM → Backup tab in Proxmox GUI.

Make sure:

- All 3 VMs are backed up in one job
- They are paused or snapshotted at the same moment
- They keep static IPs after restore
- This ensures etcd consistency.

<img width="1531" height="347" alt="prox" src="https://github.com/user-attachments/assets/59c82f5b-3b86-4f25-8dc9-ce9a5c21a802" />


## Velero: Backup Kubernetes Cluster State

```.sh
Proxmox
 ├── VM1: Kubernetes master   ← Velero server (running as pods)
 ├── VM2: Kubernetes worker
 ├── VM3: Kubernetes worker
 └── VM4: MinIO S3 server     ← Backup storage (Velero writes here)

Laptop
 ├── kubectl
 ├── velero CLI
```

- Install MinIO + create bucket + create access/secret keys.

### PART 1 Deploy MinIO on Ubuntu VM

- `sudo apt update`
- `sudo apt install -y wget`
- Download MinIO
  - `wget https://dl.min.io/server/minio/release/linux-amd64/minio`
  - `sudo mv minio /usr/local/bin/`
  - `sudo chmod +x /usr/local/bin/minio`
- `sudo mkdir -p /var/minio`
- `sudo chmod 777 /var/minio`
- Create MinIO environment file

```.sh
sudo tee /etc/default/minio > /dev/null <<EOF
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=password
MINIO_VOLUMES="/var/minio"
MINIO_OPTS="--console-address :9001"
EOF

```

- Create MinIO systemd service

```.sh
sudo tee /etc/systemd/system/minio.service > /dev/null <<EOF
[Unit]
Description=MinIO Storage Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES
EnvironmentFile=/etc/default/minio
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

- Start MinIO
  - `sudo systemctl daemon-reload`
  - `sudo systemctl enable --now minio`
  - `sudo systemctl status minio`
  - API → `http://<minio-vm-ip>:9000`
  - Web Console → `http://<minio-vm-ip>:33619`
 
 <img width="1742" height="431" alt="image" src="https://github.com/user-attachments/assets/427ac380-8b59-4f9e-8694-01e9e965c152" />


### PART 2 Create MinIO Bucket, User, and Access Keys

- Log into MinIO console
- Create a Bucket and name it velero

### PART 3 Setup Velero

#### Install Velero CLI locally

- The CLI uses kubectl context to connect to the Kubernetes API
- The CLI then installs the Velero server into the cluster
- After installation, use the CLI to control backups/restores
- install cli, unzip and add to path
- `velero version`

#### Install Velero server

- Create credentials file

```.sh
cat << EOF > credentials-velero
[default]
aws_access_key_id=minioadmin
aws_secret_access_key=password
EOF
```

- Install Velero pointing to MinIO

```.sh
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.13.0 \
    --bucket velero \
    --secret-file ./credentials-velero \
    --use-volume-snapshots=false \
    --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://ip:9000
```

- `kubectl get pods -n velero`
- `kubectl get backupstoragelocations -n velero`
- use --snapshot-location-config if using csi snapshot and --use-restic if pvs need to be backedup.
- `velero backup create full-cluster --include-namespaces '*'`
- Velero backs up all Kubernetes resources stored in etcd by querying the Kubernetes API.
- `velero get backups`
- `velero backup describe full-cluster-backup --details`
- In MinIO GUI → Bucket velero → will see backup files.

<img width="1708" height="787" alt="velero" src="https://github.com/user-attachments/assets/8bdd96c9-104d-4e80-850c-519ad29e3ac3" />


## Disaster Recovery Process (Full Cluster Restore)

- Step 1: Restore all 3 VMs from Proxmox backups
  - Boot the VMs
  - Ensure networking, hostnames, CNI network IPs are same
  - Kubelet should reconnect automatically
  - Cluster should join together without kubeadm re-init
- Step 2: Restore cluster state with Velero
  - Reinstall Velero (same install command)
  - Restore cluster state `velero restore create --from-backup full-cluster-backup`
  - This repopulates, Traefik, MetalLB, Deployments, Namespaces, Services, ConfigMaps, Secrets
- Step 3:  Restore PVC data from NFS backup

## Off-site backup

- Use AWS S3

### Proxmox VM Backup

- `aws s3 cp /var/lib/vz/dump/vzdump-qemu-105-2025_11_14-12_30_00.vma.zst s3://bucket-name/`
- Download the backup from S3 to the new Proxmox storage
- `aws s3 cp s3://bucket-name/vzdump-qemu-105-2025_11_14-12_30_00.vma.zst /var/lib/vz/dump/`
- Restore the VM in Proxmox GUI:
  - Datacenter → Node → Create VM → Restore
  - Select the .vma.zst backup file
  - Proxmox will recreate the VM with all its disks, network settings, and configuration from the backup

### Remote State Backup

- Velero can directly write to AWS S3
- Bucket: velero-backups
- Credentials: IAM user with s3:PutObject, s3:GetObject, s3:ListBucket
- Note the Access Key and Secret Key

```.sh
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.13.0 \
    --bucket velero-backups \
    --secret-file ./credentials-velero \
    --use-volume-snapshots=false \
    --backup-location-config region=eu-west-1
```
