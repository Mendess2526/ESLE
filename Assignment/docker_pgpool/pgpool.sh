#!/bin/bash

set -e
VOLUME=$PWD/keys:/keys
pg_data_dir=/var/lib/postgresql/9.3/main
DELEGATE_IP=$(cat ./delegate_ip)
MASTER_IP=""
SLAVE_IPS=()
PGPOOL1_IP=""
PGPOOL2_IP=""
nodes="$(./nodes.sh "$1")"

# check whether docker image is already available
echo -e "\e[32mCheck whether docker image locally available\e[0m"
if ! docker images | grep postmart/psql-9.3 ; then
    echo "Image is not available, need to pull first"
    if docker pull postmart/psql-9.3:latest; then
        for dir in ${nodes[*]}; do
            mkdir -p keys/"$dir"
        done
    else
        print -e "\e[33Something went wrong\e[0m"
        exit 1
    fi
fi

# installing postgresql server on all machines, and generate ssh keys
echo -e "\e[32mstarting docker containers\e[0m"
for node in ${nodes[*]}; do
    docker run \
        --name "$node" \
        --hostname="$node" \
        --privileged=true \
        -t \
        -v "$VOLUME" \
        postmart/psql-9.3:latest &

done

sleep 10

echo ""
get_ip() {
    local __ip
    __ip=$(docker inspect "$2" \
        | jq '.[0].NetworkSettings.Networks.bridge.IPAddress' -r -e) \
        || return 1
    eval "$1=$__ip"
}

for slave in $nodes
do
    while :;
    do
        ip=""
        get_ip ip "$slave" || continue
        [ -n "$ip" ] && break
        sleep 1
    done
    case "$slave" in
        master)
            MASTER_IP="$ip"
            ;;
        pgpool-1)
            PGPOOL1_IP="$ip"
            ;;
        pgpool-2)
            PGPOOL2_IP="$ip"
            ;;
        slave*)
            SLAVE_IPS+=("$ip")
            ;;
    esac
done

echo "${SLAVE_IPS[@]}"

echo "................................"
echo -e "\e[0m"
echo "................................"
echo "................................"
echo -e "\e[32mStarting ssh\e[0m"
docker exec master /etc/init.d/ssh start
docker exec pgpool-2 /etc/init.d/ssh start
docker exec slave1 /etc/init.d/ssh start
docker exec slave2 /etc/init.d/ssh start
docker exec pgpool-1 /etc/init.d/ssh start
echo "................................"
echo -e "\e[95mStopping psql\e[0m"
docker exec master /etc/init.d/postgresql stop
docker exec slave1 /etc/init.d/postgresql stop
docker exec slave2 /etc/init.d/postgresql stop

echo -e "\e[32mGenerating ssh keys\e[0m"

for node in ${nodes[*]}; do
    docker exec "$node" bash -c "mkdir -p /keys/$node";
    docker exec "$node" bash -c "ssh-keygen  -b 2048 -t rsa -f /keys/$node/id_rsa -q " ;
    docker exec "$node" bash -c "mkdir /root/.ssh/" ;
    docker exec "$node" bash -c "cp /keys/$node/id_rsa /root/.ssh/"
    docker exec "$node" bash -c "mkdir -p /var/lib/postgresql/.ssh/" ;
done

for node in ${nodes[*]}; do
    docker exec "$node" bash -c "cd /keys/ && find . -type f -name id_rsa.pub -exec cat {} \; | tee /root/.ssh/authorized_keys /var/lib/postgresql/.ssh/authorized_keys"
    docker exec "$node" bash -c "echo '$(cat ~/.ssh/id_rsa.pub)' >> /root/.ssh/authorized_keys"
done

echo "................................"
echo -e "\e[32mAdding entries to /etc/hosts\e[0m"
echo -e "\e[95m:::::for master"
docker exec master bash -c "echo ${SLAVE_IPS[0]} slave1 >> /etc/hosts"
docker exec master bash -c "echo ${SLAVE_IPS[1]} slave2 >> /etc/hosts"
docker exec master bash -c "echo $PGPOOL2_IP pgpool-2 >> /etc/hosts"
docker exec master bash -c "echo $PGPOOL1_IP pgpool-1 >> /etc/hosts"

echo -e "\e[95m:::::for slave1"
docker exec slave1 bash -c "echo ${SLAVE_IPS[1]} slave2 >> /etc/hosts"
docker exec slave1 bash -c "echo $MASTER_IP master >> /etc/hosts"
docker exec slave1 bash -c "echo $PGPOOL2_IP pgpool-2 >> /etc/hosts"
docker exec slave1 bash -c "echo $PGPOOL1_IP pgpool-1 >> /etc/hosts"

echo -e "\e[95m:::::for slave2"
docker exec slave2 bash -c "echo $MASTER_IP master >> /etc/hosts"
docker exec slave2 bash -c "echo ${SLAVE_IPS[0]} slave1 >> /etc/hosts"
docker exec slave2 bash -c "echo $PGPOOL2_IP pgpool-2 >> /etc/hosts"
docker exec slave2 bash -c "echo $PGPOOL1_IP pgpool-1 >> /etc/hosts"

echo -e "\e[95m:::::for pgpool-2"
docker exec pgpool-2 bash -c "echo $MASTER_IP master >> /etc/hosts"
docker exec pgpool-2 bash -c "echo ${SLAVE_IPS[0]} slave1 >> /etc/hosts"
docker exec pgpool-2 bash -c "echo ${SLAVE_IPS[1]} slave2 >> /etc/hosts"
docker exec pgpool-2 bash -c "echo $PGPOOL1_IP pgpool-1 >> /etc/hosts"

echo -e "\e[95m:::::for pgpool-1"
docker exec pgpool-1 bash -c "echo $MASTER_IP master >> /etc/hosts"
docker exec pgpool-1 bash -c "echo ${SLAVE_IPS[0]} slave1 >> /etc/hosts"
docker exec pgpool-1 bash -c "echo $PGPOOL2_IP pgpool-2 >> /etc/hosts"
docker exec pgpool-1 bash -c "echo ${SLAVE_IPS[1]} slave2 >> /etc/hosts"

echo "................................"
echo -e "\e[32mtesting ssh"
for node in ${nodes[*]}; do
    echo -e "\e[95m:::::::::::on $node\e[0m"
    docker exec "$node" bash -c 'for name in $(/keys/nodes.sh '"$1"'); do ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no postgres@$name : ; done'
done

echo "Copy known_hosts to postgres dir"
for node in ${nodes[*]}; do
    docker exec "$node" bash -c "cp /root/.ssh/known_hosts /var/lib/postgresql/.ssh/" ;
done
echo -e "\e[32mCopy postgres config file\e[0m"
docker exec master cp /keys/master_postgresql.conf /etc/postgresql/9.3/main/postgresql.conf
docker exec slave1 cp /keys/slave_postgresql.conf /etc/postgresql/9.3/main/postgresql.conf
docker exec slave2 cp /keys/slave_postgresql.conf /etc/postgresql/9.3/main/postgresql.conf

echo -e "\e[32mAdding hosts for replication in pg_hba.conf"
echo -e "\e[95m:::::::::on master\e[0m"
docker exec master bash -c "echo host replication repl ${SLAVE_IPS[0]}/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec master bash -c "echo host replication repl ${SLAVE_IPS[1]}/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec master bash -c "echo host all pgpool $PGPOOL2_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec master bash -c "echo host all all $PGPOOL2_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec master bash -c "echo host all all $PGPOOL1_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec master bash -c "sed -i -r '/^local +all +postgres +/ s/peer/trust/' /etc/postgresql/9.3/main/pg_hba.conf"
docker exec master bash -c 'cat /etc/postgresql/9.3/main/pg_hba.conf'

echo -e "\e[95m:::::::::on slave1\e[0m"
docker exec slave1 bash -c "echo host replication repl $MASTER_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave1 bash -c "echo host replication repl ${SLAVE_IPS[1]}/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave1 bash -c "echo host all pgpool $PGPOOL2_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave1 bash -c "echo host all all $PGPOOL2_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave1 bash -c "echo host all all $PGPOOL1_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave1 bash -c "sed -i -r '/^local +all +postgres +/ s/peer/trust/' /etc/postgresql/9.3/main/pg_hba.conf"

echo -e "\e[95m:::::::::on slave2\e[0m"
docker exec slave2 bash -c "echo host replication repl $MASTER_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave2 bash -c "echo host replication repl ${SLAVE_IPS[0]}/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave2 bash -c "echo host all pgpool $PGPOOL2_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave2 bash -c "echo host all all $PGPOOL2_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave2 bash -c "echo host all all $PGPOOL1_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec slave2 bash -c "sed -i -r '/^local +all +postgres +/ s/peer/trust/' /etc/postgresql/9.3/main/pg_hba.conf"

echo -e "\e[95m:::::::::on pgpool-2\e[0m"
docker exec pgpool-2 bash -c "echo host all all $MASTER_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec pgpool-2 bash -c "echo host all all ${SLAVE_IPS[0]}/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec pgpool-2 bash -c "echo host all all ${SLAVE_IPS[1]}/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec pgpool-2 bash -c "echo host all all $PGPOOL1_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec pgpool-2 bash -c "sed -i -r '/^local +all +postgres +/ s/peer/trust/' /etc/postgresql/9.3/main/pg_hba.conf"

echo -e "\e[95m:::::::::on pgpool-1\e[0m"
docker exec pgpool-1 bash -c "echo host all all $MASTER_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec pgpool-1 bash -c "echo host all all ${SLAVE_IPS[0]}/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec pgpool-1 bash -c "echo host all all ${SLAVE_IPS[1]}/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec pgpool-1 bash -c "echo host all all $PGPOOL2_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec pgpool-1 bash -c "sed -i -r '/^local +all +postgres +/ s/peer/trust/' /etc/postgresql/9.3/main/pg_hba.conf"

echo -e "\e[95mcreating user database on master\e[0m"
docker exec master /etc/init.d/postgresql start
docker exec master bash -c "sudo -u postgres psql --file=/keys/create_user_master.sql "

echo -e "\e[32mCreating base backup  on master\e[0m"
docker exec master bash -c "/keys/base_backup_master.sh"

echo -e "\e[32mCopy base_backup.tar to slaves\e[0m"
docker exec master bash -c "scp /var/lib/postgresql/9.3/base_backup.tar postgres@slave1:~"
docker exec master bash -c "scp /var/lib/postgresql/9.3/base_backup.tar postgres@slave2:~"

echo -e "\e[32mSlave1 Replication\e[0m"
docker exec slave1 bash -c "/keys/slave_replication.sh"
echo -e "\e[32mSlave2 Replication\e[0m"
docker exec slave2 bash -c "/keys/slave_replication.sh"

echo -e "\e[32mInstalling pgpool to pgpool-2\e[0m"
docker exec pgpool-2 apt-get install -q -y  pgpool2 postgresql-9.3-pgpool2 arping
docker exec pgpool-1 apt-get install -q -y  pgpool2 postgresql-9.3-pgpool2 arping
docker exec pgpool-2 /etc/init.d/pgpool2 stop
docker exec pgpool-1 /etc/init.d/pgpool2 stop
docker exec pgpool-2 bash -c "/keys/pgpool-2_pgpool.sh"
docker exec pgpool-2 bash -c "mkdir -p /var/lib/postgresql/bin"
docker exec pgpool-2 bash -c "cp /keys/pgpool-2_failover.sh /var/lib/postgresql/bin/failover.sh"

docker exec pgpool-1 bash -c "/keys/pgpool-1_pgpool.sh"
docker exec pgpool-1 bash -c "mkdir -p /var/lib/postgresql/bin"
docker exec pgpool-1 bash -c "cp /keys/pgpool-2_failover.sh /var/lib/postgresql/bin/failover.sh"

docker exec master bash -c "cp /keys/pgpool-recovery.so /usr/lib/postgresql/9.3/lib/pgpool-recovery.so"
docker exec slave1 bash -c "cp /keys/pgpool-recovery.so /usr/lib/postgresql/9.3/lib/pgpool-recovery.so"
docker exec slave2 bash -c "cp /keys/pgpool-recovery.so /usr/lib/postgresql/9.3/lib/pgpool-recovery.so"

docker exec master bash -c "cp /keys/basebackup.sh $pg_data_dir/basebackup.sh"
docker exec slave1 bash -c "cp /keys/basebackup.sh $pg_data_dir/basebackup.sh"
docker exec slave2 bash -c "cp /keys/basebackup.sh $pg_data_dir/basebackup.sh"

docker exec master bash -c "cp /keys/pgpool_remote_start $pg_data_dir/pgpool_remote_start"
docker exec slave1 bash -c "cp /keys/pgpool_remote_start $pg_data_dir/pgpool_remote_start"
docker exec slave2 bash -c "cp /keys/pgpool_remote_start $pg_data_dir/pgpool_remote_start"

docker exec master bash -c "cp /keys/pgpool-recovery $pg_data_dir/pgpool-recovery"
docker exec slave1 bash -c "cp /keys/pgpool-recovery $pg_data_dir/pgpool-recovery"
docker exec slave2 bash -c "cp /keys/pgpool-recovery $pg_data_dir/pgpool-recovery"

echo -e "\e[32mStarting pool on pgpool-2\e[0m"
docker exec pgpool-2 bash -c "/keys/pgpool-2_start.sh"
sleep 2.5
docker exec pgpool-1 bash -c "/keys/pgpool-2_start.sh"

echo -e "\e[32mAdding sample database\e[0m"
psql -h "$DELEGATE_IP" -p 9999 -U postgres </dev/null
