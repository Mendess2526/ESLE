#!/bin/bash

set -e
VOLUME=$PWD/keys:/keys
pg_data_dir=/var/lib/postgresql/9.3/main
#DELEGATE_IP=$(cat ./delegate_ip)
MASTER_IP=""
SLAVE_IPS=()
PGPOOL_IP=""
nodes="$(./nodes.sh "$1")"
echo "$nodes" | { grep -c slave || true; } > /tmp/num_nodes

get_slave_ip() {
    number="$(echo "$1" | grep -oP '[0-9]+$')"
    echo "${SLAVE_IPS[$(( number - 1 ))]}"
}

get_ip() {
    local __ip
    __ip=$(docker inspect "$2" \
        | jq '.[0].NetworkSettings.Networks.bridge.IPAddress' -r -e) \
        || return 1
    eval "$1=$__ip"
}

# check whether docker image is already available
echo -e "\e[32mCheck whether docker image locally available\e[0m"
if ! docker images | grep postmart/psql-9.3 ; then
    echo "Image is not available, need to pull first"
    if docker pull postmart/psql-9.3:latest; then
        for dir in ${nodes[*]}; do
            mkdir -p keys/"$dir"
        done
    else
        echo -e "\e[33Something went wrong\e[0m"
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

    disown

done

sleep 1

echo ""
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
        pgpool)
            PGPOOL_IP="$ip"
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
docker exec master /etc/init.d/ssh start &
docker exec pgpool /etc/init.d/ssh start &
for slave in $(echo "$nodes" | grep slave); do
    docker exec "$slave" /etc/init.d/ssh start &
done
wait

echo "................................"
echo -e "\e[95mStopping psql\e[0m"
docker exec master /etc/init.d/postgresql stop &
for slave in $(echo "$nodes" | grep slave); do
    docker exec "$slave" /etc/init.d/postgresql stop &
done
wait

echo -e "\e[32mGenerating ssh keys\e[0m"
for node in ${nodes[*]}; do
    docker exec "$node" bash -c "mkdir -p /keys/$node"
    docker exec "$node" bash -c "ssh-keygen  -b 2048 -t rsa -f /keys/$node/id_rsa -q -N ''"
    docker exec "$node" bash -c "mkdir /root/.ssh/"
    docker exec "$node" bash -c "cp /keys/$node/id_rsa /root/.ssh/"
    docker exec "$node" bash -c "mkdir -p /var/lib/postgresql/.ssh/"
done

for node in ${nodes[*]}; do
    docker exec "$node" bash -c "cd /keys/ && find . -type f -name id_rsa.pub -exec cat {} \; | tee /root/.ssh/authorized_keys /var/lib/postgresql/.ssh/authorized_keys" &>/dev/null
    docker exec "$node" bash -c "echo '$(cat ~/.ssh/id_rsa.pub)' >> /root/.ssh/authorized_keys"
done

echo "................................"
echo -e "\e[32mAdding entries to /etc/hosts\e[0m"
echo -e "\e[95m:::::for master"
for slave in $(echo "$nodes" | grep slave); do
    docker exec master bash -c "echo $(get_slave_ip "$slave") $slave >> /etc/hosts"
done
docker exec master bash -c "echo $PGPOOL_IP pgpool >> /etc/hosts"

for slave in $(echo "$nodes" | grep slave); do
    echo -e "\e[95m:::::for $slave"
    for other_slave in $(echo "$nodes" | grep slave | grep -v "$slave"); do
        docker exec "$slave" bash -c "echo $(get_slave_ip "$other_slave") slave2 >> /etc/hosts"
    done
    docker exec "$slave" bash -c "echo $MASTER_IP master >> /etc/hosts"
    docker exec "$slave" bash -c "echo $PGPOOL_IP pgpool >> /etc/hosts"
done

echo -e "\e[95m:::::for pgpool"
docker exec pgpool bash -c "echo $MASTER_IP master >> /etc/hosts"
for slave in $(echo "$nodes" | grep slave); do
    docker exec pgpool bash -c "echo $(get_slave_ip "$slave") $slave >> /etc/hosts"
done

echo "................................"
echo -e "\e[32mtesting ssh"
for node in ${nodes[*]}; do
    echo -e "\e[95m:::::::::::on $node\e[0m"
    docker exec "$node" bash -c 'for name in $(/keys/nodes.sh '"$1"'); do ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no postgres@$name : ; done' &
done
wait

echo "Copy known_hosts to postgres dir"
for node in ${nodes[*]}; do
    docker exec "$node" bash -c "cp /root/.ssh/known_hosts /var/lib/postgresql/.ssh/" &
done
echo -e "\e[32mCopy postgres config file\e[0m"
docker exec master cp /keys/master_postgresql.conf /etc/postgresql/9.3/main/postgresql.conf &
for slave in $(echo "$nodes" | grep slave)
do
    docker exec "$slave" cp /keys/slave_postgresql.conf /etc/postgresql/9.3/main/postgresql.conf &
done
wait

echo -e "\e[32mAdding hosts for replication in pg_hba.conf"
echo -e "\e[95m:::::::::on master\e[0m"
for slave in $(echo "$nodes" | grep slave); do
    docker exec master bash -c "echo host replication repl $(get_slave_ip "$slave")/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
done
docker exec master bash -c "echo host all pgpool $PGPOOL_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec master bash -c "echo host all all $PGPOOL_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
docker exec master bash -c "sed -i -r '/^local +all +postgres +/ s/peer/trust/' /etc/postgresql/9.3/main/pg_hba.conf"

for slave in $(echo "$nodes" | grep 'slave'); do
    echo -e "\e[95m:::::::::on $slave\e[0m"
    docker exec "$slave" bash -c "echo host replication repl $MASTER_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
    for other_slave in $(echo "$nodes" | grep 'slave' | grep -v "$slave"); do
        docker exec "$slave" bash -c "echo host replication repl $(get_slave_ip "$other_slave")/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
    done
    docker exec "$slave" bash -c "echo host all pgpool $PGPOOL_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
    docker exec "$slave" bash -c "echo host all all $PGPOOL_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
    docker exec "$slave" bash -c "sed -i -r '/^local +all +postgres +/ s/peer/trust/' /etc/postgresql/9.3/main/pg_hba.conf"
done

echo -e "\e[95m:::::::::on pgpool\e[0m"
docker exec pgpool bash -c "echo host all all $MASTER_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
for slave in $(echo "$nodes" | grep slave); do
    docker exec pgpool bash -c "echo host all all $(get_slave_ip "$slave")/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"
done
docker exec pgpool bash -c "echo host all all $PGPOOL_IP/16 trust >> /etc/postgresql/9.3/main/pg_hba.conf"

echo -e "\e[95mcreating user database on master\e[0m"
docker exec master /etc/init.d/postgresql start
docker exec master bash -c "sudo -u postgres psql --file=/keys/create_user_master.sql "

echo -e "\e[32mCreating base backup on master\e[0m"
docker exec master bash -c "/keys/base_backup_master.sh"

echo -e "\e[32mCopy base_backup.tar to slaves\e[0m"
for slave in $(echo "$nodes" | grep slave) ; do
    docker exec master bash -c "scp /var/lib/postgresql/9.3/base_backup.tar postgres@$slave:~" &
done
wait

for slave in $(echo "$nodes" | grep slave) ; do
    echo -e "\e[32m$slave Replication\e[0m"
    docker exec "$slave" bash -c "/keys/slave_replication.sh" &
done
wait

echo -e "\e[32mInstalling pgpool to pgpool\e[0m"
docker exec pgpool apt-get install -qq -y \
    pgpool2 postgresql-9.3-pgpool2 arping &>/dev/null
docker exec pgpool /etc/init.d/pgpool2 stop
cp keys/pgpool.conf keys/pgpool-gen.conf

for slave in $(echo "$nodes" | grep slave) ; do
    number="$(echo "$slave" | grep -oP '[0-9]+$')"
    {
        echo
        echo "backend_hostname$number = $slave"
        echo "backend_port$number = 5432"
        echo "backend_weight$number = 1"
        echo "backend_data_directory$number = '/var/lib/postgresql/9.3/main'"
        echo "backend_flag$number = 'ALLOW_TO_FAILOVER'"
    } >> keys/pgpool-gen.conf
done

docker exec pgpool bash -c "/keys/pgpool-2_pgpool.sh"
docker exec pgpool bash -c "mkdir -p /var/lib/postgresql/bin"
docker exec pgpool bash -c "cp /keys/pgpool-2_failover.sh /var/lib/postgresql/bin/failover.sh"

docker exec master bash -c "cp /keys/pgpool-recovery.so /usr/lib/postgresql/9.3/lib/pgpool-recovery.so" &
for slave in $(echo "$nodes" | grep slave) ; do
    docker exec "$slave" bash -c "cp /keys/pgpool-recovery.so /usr/lib/postgresql/9.3/lib/pgpool-recovery.so" &
done
wait

docker exec master bash -c "cp /keys/basebackup.sh $pg_data_dir/basebackup.sh" &
for slave in $(echo "$nodes" | grep slave) ; do
    docker exec "$slave" bash -c "cp /keys/basebackup.sh $pg_data_dir/basebackup.sh" &
done
wait

docker exec master bash -c "cp /keys/pgpool_remote_start $pg_data_dir/pgpool_remote_start" &
for slave in $(echo "$nodes" | grep slave) ; do
    docker exec "$slave" bash -c "cp /keys/pgpool_remote_start $pg_data_dir/pgpool_remote_start" &
done
wait

docker exec master bash -c "cp /keys/pgpool-recovery $pg_data_dir/pgpool-recovery" &
for slave in $(echo "$nodes" | grep slave) ; do
    docker exec "$slave" bash -c "cp /keys/pgpool-recovery $pg_data_dir/pgpool-recovery" &
done
wait

echo -e "\e[32mStarting pool on pgpool\e[0m"
docker exec pgpool bash -c "/keys/pgpool-2_start.sh"

docker update --cpus=0.05 master &
docker update --cpus=0.05 pgpool &
for slave in $(echo "$nodes" | grep slave) ; do
    docker update --cpus=0.05 "$slave" &
done
wait

echo -e "\e[32mAdding sample database\e[0m"
echo PGPOOL IP $PGPOOL_IP
