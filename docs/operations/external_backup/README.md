# external_backup process for my Windows 11/wsl2 workstation

for now, simply export the latest restic backup file to your local machine
using `rsync` on a systemd timer

inside wsl2:

```bash

# 1. create the service file at `/etc/systemd/system/joplin-rsync.service`
sudo cp joplin-rsync.service /etc/systemd/system/joplin-rsync.service

#2. create the timer file at `/etc/systemd/system/joplin-rsync.timer`
sudo cp joplin-rsync.timer /etc/systemd/system/joplin-rsync.timer

#3. enable them:

sudo systemctl daemon-reload
sudo systemctl enable --now joplin-rsync.timer
sudo systemctl list-timers --all | grep joplin-rsync

#  4. validate the new joplin rsync timer is set:

systemctl list-timers

# 5. after an hour or two validate the timer ran rsync successfully

journalctl -u joplin-rsync.timer --since "today"

```
