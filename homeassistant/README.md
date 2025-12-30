# Home Assistant

- CAMERA → Frigate → Home Assistant → Automations

```.sh
Ubuntu VM (in Proxmox)
│
├── Docker + Docker Compose
│
├── Home Assistant  ← Controls & Dashboard
└── Frigate         ← AI detection, recording to NFS/MinIO
```

Data Flow:

1. Camera RTSP feed → Frigate
2. Frigate detects objects (person, car, dog, cat)
3. Frigate generates events and clips
4. Home Assistant reads events and creates entities → Automations trigger notifications/actions

Control Frigate in Home Assistant:

- Settings → Add Integration → Search “Frigate”
- Frigate detects & publishes → Home Assistant reads & creates entities

| Component          | Purpose                                      |
| ------------------ | -------------------------------------------- |
| **Frigate**        | Detects motion & generates camera entities   |
| **Home Assistant** | Displays entities & uses them in automations |

Camera Entities & Automations :

- Home Assistant → Developer Tools → States
- Search for camera name > This will show all Frigate entities created automatically.
- Every time add/edit automation files `docker restart homeassistant`

PostgreSQL Optimization:

- `docker exec -it homeassistant-db bash`
- `nano /var/lib/postgresql/data/postgresql.conf`
- `docker restart homeassistant-db`

```.sh
shared_buffers = 256MB
work_mem = 32MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.8
max_wal_size = 1GB
effective_cache_size = 512MB
```
