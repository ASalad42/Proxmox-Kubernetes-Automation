# Home Assistant

- CAMERA → Frigate → MQTT → Home Assistant → Entities + Automations

```.sh
Ubuntu VM (in Proxmox)
│
├── Docker + Docker Compose
│
├── Home Assistant  ← Controls & Dashboard
│       ↑
│       │  MQTT (events, detections, snapshots)
│       │
└── Frigate         ← AI detection, motion, recording, snapshots
        │
        │  RTSP
        ▼
     Camera (outside_cam)
```

Data Flow:

1. Camera RTSP feed → Frigate
2. Frigate detects objects (person, car, dog, cat)
3. Frigate publishes events, snapshots, and clips via MQTT
4. Home Assistant subscribes to MQTT → Creates entities
5. Automations in Home Assistant trigger notifications/actions

Setup:

- Go to HA web ui and add MQTT
  - Settings → Devices & Services → Add Integration → MQTT
  - Broker: 127.0.0.1
  - Port: 1883
  - Check connection is working:
  - `docker logs mqtt`
  - `docker logs frigate | grep mqtt`
- Add HACS:
  - `docker exec -it homeassistant bash`
  - `apk add --no-cache git zip || apt update && apt install -y git zip`
  - `cd /config`
  - `wget -O - https://get.hacs.xyz | bash -`
  - exit and `docker restart homeassistant`
  - Install HACS - Settings → Devices & Services → Add Integration → HACS
  - `docker restart homeassistant`
  - After restart, HACS appears
- Add frigate → Open HACS → Search for Frigate → Download
  - Restart Home Assistant container again `docker restart homeassistant`
  - Settings → Devices & Services → Add Integration → Search “Frigate”
  - Enter Frigate URL `http://ip:5000`
  - Check Settings → Devices & Services → Frigate → Devices for camera and friagte device.
  - Check newly created entities - Developer Tools → States
  - Camera entities for Frigate camera
  - Binary sensors for tracked objects (person, car, etc.)
  - Event sensors for motion/alerts
  - Example: camera.outside_cam, binary_sensor.outside_cam_person
- create automations
- setup tailscale tunnel for remote access

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
