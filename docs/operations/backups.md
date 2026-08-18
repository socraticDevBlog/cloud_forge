---
author: socraticDev
date: 2026-08-17
status: proposed
---

# backup strategy

## Joplin

Joplin is an open-source note-taking app. Joplin Server runs an API server backed by PostgreSQL. Users connect from clients (Android, macOS, Windows, etc.) and all note data lives in the database and application configuration.

The backup strategy uses `restic` because it is efficient, encrypted, and supports snapshot-based recovery. It keeps backups small by storing deltas instead of complete copies every time.

## What is backed up

The hourly systemd backup job performs the following actions:

1. Reads the Joplin app directory from `/opt/stacks/joplin`
2. Exports PostgreSQL data with `pg_dumpall`
3. Saves the PostgreSQL dump in `/var/backups/joplin/postgres/joplin.sql`
4. Backs up both the app directory and the local dump into the restic repository at `/var/backups/restic/joplin`

This means the restic repository contains the files needed to recover the service, including:

- `/opt/stacks/joplin/docker-compose.yml`
- `/opt/stacks/joplin/.env`
- any future app configuration files in the same directory
- `/var/backups/joplin/postgres/joplin.sql` (full logical PostgreSQL dump)

The PostgreSQL dump is the database backup. It is the file that contains the actual Joplin data and schema. The restic snapshot is the wrapper around that data, plus the app configuration needed to stand the service back up.

## How the backup runs

A systemd timer runs the Joplin backup service every hour:

- service: `/etc/systemd/system/restic-joplin-backup.service`
- timer: `/etc/systemd/system/restic-joplin-backup.timer`

The script does the following:

```bash
# create a temporary PostgreSQL dump
DB_CONTAINER="$(docker compose -f /opt/stacks/joplin/docker-compose.yml ps -q db)"
docker exec -e PGPASSWORD="${DB_PASSWORD}" "${DB_CONTAINER}" pg_dumpall -U "${DB_USER}" > /var/backups/joplin/postgres/joplin.sql

# back up the config and generated dump into restic
restic backup --tag joplin --one-file-system /opt/stacks/joplin /var/backups/joplin

# keep only the newest backup snapshot
restic forget --prune --keep-last 1
```

This leaves the repo with a single retained snapshot, which satisfies the "latest only" requirement.

## Backup copy to local machine

The VM repository can be mirrored to a safer local machine with rsync:

```bash
#from local machine (not the VM on which Joplin-server runs)

rsync -avz --delete azureadmin@YOUR_VM_IP:/var/backups/restic/ /mnt/c/Users/socdev/backup_joplin
```

Then inspect the backup repository locally:

```bash
RESTIC_PASSWORD='your-restic-password' restic snapshots -r /mnt/c/Users/socdev/backup_joplin/joplin
```

## Restore process

The operator should test the restore procedure regularly. The restore process is:

1. Stop the current Joplin stack
2. Restore the latest snapshot into a temporary directory
3. Recover the app files and database dump
4. Re-create the service or restore the app into a fresh deployment
5. Import the PostgreSQL dump back into PostgreSQL
6. Start the service and verify access

### Example restore workflow

```bash
# set the repository password
export RESTIC_PASSWORD='your-restic-password'

# list snapshots
restic -r /mnt/c/Users/socdev/backup_joplin snapshots

# restore the latest snapshot into a temporary location
restic -r /mnt/c/Users/socdev/backup_joplin restore latest --target /tmp/joplin-restore
```

After restore:

```bash
ls -R /tmp/joplin-restore
```

You should see the application files and the dump file under the restored tree. In a real recovery, the operator would then copy the Joplin config back into `/opt/stacks/joplin` and import the dump into PostgreSQL.

### Recover the PostgreSQL database

```bash
# copy the dump back to the server or restore host
scp /tmp/joplin-restore/var/backups/joplin/postgres/joplin.sql azureadmin@YOUR_VM_IP:/tmp/joplin.sql

# restore it into PostgreSQL
docker exec -i <postgres_container_id> psql -U postgres -d postgres < /tmp/joplin.sql
```

For a full repair workflow, the operator can:

```bash
# stop the current app
cd /opt/stacks/joplin
docker compose down

# restore the app files from the snapshot
cp -a /tmp/joplin-restore/opt/stacks/joplin/. /opt/stacks/joplin/

# start the app again
docker compose up -d
```

## Operator drill (must be tested regularly)

The restore process should be exercised at least once per month, or after any major configuration change.

### Drill procedure

1. Pick a test date in the calendar and record it.
2. Confirm the latest restic snapshot exists.
3. Restore the snapshot to `/tmp/joplin-restore`.
4. Validate that the dump file exists and is readable.
5. Validate that the Docker Compose files and `.env` file are restored.
6. If a test database is available, import the SQL dump into a temporary database and verify the schema is valid.
7. Record the result in the ops log.
8. Remove the temporary restore directory after verification.

### Example drill commands

```bash
export RESTIC_PASSWORD='your-restic-password'
restic -r /mnt/c/Users/socdev/backup_joplin snapshots
restic -r /mnt/c/Users/socdev/backup_joplin restore latest --target /tmp/joplin-restore
ls /tmp/joplin-restore/var/backups/joplin/postgres/
file /tmp/joplin-restore/var/backups/joplin/postgres/joplin.sql
```

If the SQL dump looks valid, the restore path is considered tested.

## Operational note

The key rule is: the backup is only useful if the restore path has been tested. A restic snapshot that has not been restored is not a proven backup.

The operator should treat the restore drill as mandatory and should keep a small log of the date and result.
