# Media Apps

- `kubectl apply -f radarr.yml`
  - `kubectl exec -it deploy/radarr -n homelab -- bash`
  - `mkdir -p /data/downloads /data/movies /data/tvseries`
  - check on other apps to see if these folders exist due to nfs-share
  - connect qbittorrent using host as `qbittorrent.homelab.svc.cluster.local`
  - set root folder as `/data/movies`. no remote path mapping is need for this work.
  - once movie downlaods check if hardlink worked - If the inode numbers are the same, it’s a hardlink — only one physical file exists.
    - `ls -i /data/downloads/MovieName.mp4`
    - `ls -i /data/movies/MovieName/MovieName.mp4`
- `kubectl apply -f sonarr.yml`
- `kubectl label node k8s-worker-2 hardware=gpu` and `kubectl get nodes --show-labels`
- `kubectl apply -f jellyfin.yml`
  - set movies libary to /data/movies
- `kubectl apply -f prowlarr.yml`
  - when connecting qbittorrent host is `qbittorrent.homelab.svc.cluster.local`
  - when connecting radarr app use api key from radarr
    - prowlarr server = `http://prowlarr.homelab.svc.cluster.local:9696`
    - radarr server = `http://radarr.homelab.svc.cluster.local:7878`
- `kubectl apply -f qbittorrent.yml`
  - use `kubectl logs -n homelab qbittorrent-694` to get tmp password
  - tools > options > webui > change password
  - set downloads folder as `data/downlaods`
- `kubectl apply -f homarr.yml`
- `kubectl apply -f filebrowser.yml`
- `kubectl get all -n homelab -o wide`

## hardware acceleration (Intel QuickSync)

- To enable Intel vt and VT-d on HP EliteDesk 800 G2 SFF, restart the computer and press F10 to enter the BIOS.
  - Navigate to the Advanced tab, select System Options – enable both
- Intel Quick Sync - PCI passthrough requires **IOMMU support**.
- Jellyfin Admin > Playback > Transcoding, should be able to select Intel Quick Sync as the hardware acceleration method.
- **QEMU Guest Agent Enabled**. `sudo apt install qemu-guest-agent -y` so in vm sumarry i can see the ip. reboot after running the command.

### Enable IOMMU in Proxmox (host)

- node > shell > `nano /etc/default/grub`
- GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
- `update-grub`
- reboot
- `dmesg | grep -e DMAR -e IOMMU` for Intel (VT-d) systems
- `dmesg | grep 'remapping'`

### Add GPU passthrough to VM

In the Proxmox GUI:

- Shut down the VM.
- Go to Hardware → Add → PCI Device > raw device
- the dropdown should show all PCI devices
- Select Intel Corporation HD Graphics 530.
- Enable all functions
- Save and Start the VM.
- Now check for /dev/dri: `ls -l /dev/dri`

Prepare the Ubuntu VM:

- Passing the Intel GPU to the VM exposes the hardware to the VM. But the VM does not automatically know how to talk to it.
- `sudo apt update`
- `sudo apt install -y xserver-xorg-video-intel intel-media-va-driver-non-free vainfo`
- `sudo modprobe i915`
- `sudo apt install --install-recommends linux-generic`
- `sudo reboot`
- `lsmod | grep i915`
- `ls -l /dev/dri`

```.sh

ubuntu@k8s-worker-2:~$ ls -l /dev/dri
total 0
crw-rw---- 1 root video  226,   0 card0
crw-rw---- 1 root render 226, 128 renderD128
```

Note:

- Adding the PCI device in the GUI doesn’t automatically detach it from an old VM and rebind it to vfio-pci. Have to handle it carefully.
- old and new vm must be stopped. PCI passthrough cannot be hot-swapped for a running VM in Proxmox. Remove pci device from old vm
- use `lspci -nnk -d 8086:1912` in proxmox shell to see if its free for new vm and if it is then add to new vm.
