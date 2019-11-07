#!/bin/sh
cd /var/lib/postgresql/9.3 || exit 1
sudo -u postgres mv /var/lib/postgresql/base_backup.tar .
sudo -u postgres rm -rf main/
sudo -u postgres tar -xf base_backup.tar
sudo -u postgres mkdir -p main/pg_xlog/archive_status
sudo -u postgres cp /keys/slave_recovery.conf main/recovery.conf && /etc/init.d/postgresql start
