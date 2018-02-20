#!/bin/bash
#####################################################################################################
# This script will install Postgres as Master Node on your Ubuntu 16.04 server.
# Author: Mohamed Hammad
#----------------------------------------------------------------------------------------------------
# Make a new file:
# sudo nano 01-master-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x 01-master-install.sh
# Execute the script to install Postgres:
# sudo ./01-master-install.sh
#######################################################################################################

ODOO_DB_USER="odoo"
ODOO_DB_PASS="odoo"
MASTER_IP="192.168.1.10"
SLAVE_IP="192.168.1.11"
SLAVE_USER="sammy"
SLAVE_PASS="sammy"
NETWORK="192.168.1.0/24"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt update
sudo apt upgrade -yV

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo apt install postgresql-9.5 postgresql-9.5-repmgr postgresql-client-9.5 sshpass -yV

echo -e "\n---- Configure password-less SSH ----"
sudo su - postgres -c "ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''"

echo -e "\n---- Copy RSA keys to Node2 ----"
sudo su - postgres -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
sudo su - postgres -c "chmod go-rwx ~/.ssh/*"
sudo su - postgres -c "ssh-keyscan -H $SLAVE_IP >> ~/.ssh/known_hosts"
sudo su - postgres -c "sshpass -p $SLAVE_PASS scp ~/.ssh/id_rsa.pub ~/.ssh/id_rsa ~/.ssh/authorized_keys $SLAVE_USER@$SLAVE_IP:"

echo -e "\n---- Configure repmgr User & Database ----"
sudo su - postgres -c "createuser -s repmgr" 2> /dev/null || true
sudo su - postgres -c "createdb repmgr -O repmgr"

echo -e "\n---- Create Odoo User ----"
sudo su - postgres -c "createuser -s $ODOO_DB_USER" 2> /dev/null || true
sudo su - postgres -c "psql -c \"ALTER USER $ODOO_DB_USER WITH PASSWORD '$ODOO_DB_PASS';\""

echo -e "\n---- Configure PostgreSQL Replication Settings ----"
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i "s/#wal_level = minimal/wal_level = hot_standby/g" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i "s/#archive_mode = off/archive_mode = on/g" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i "s/#archive_command = ''/archive_command = 'cd .'/g" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i "s/#max_wal_senders = 0/max_wal_senders = 10/g" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i "s/#max_replication_slots = 0/max_replication_slots = 1/g" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'repmgr_funcs'/g" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i "s/#hot_standby = off/hot_standby = on/g" /etc/postgresql/9.5/main/postgresql.conf

echo -e "\n---- Configure PostgreSQL Settings ----"
echo "host    repmgr          repmgr     $NETWORK     trust
host    replication     repmgr     $NETWORK     trust
host    all     all     $NETWORK     trust" | sudo tee -a /etc/postgresql/9.5/main/pg_hba.conf

echo -e "\n---- Restart PostgreSQL Service ----"
sudo service postgresql restart

echo -e "\n---- Configure Replication Manager ----"
sudo mkdir -p /etc/repmgr
echo "cluster=Odoo
node=1
node_name=node1
use_replication_slots=1
conninfo='host=$MASTER_IP user=repmgr dbname=repmgr'
pg_bindir=/usr/lib/postgresql/9.5/bin" | sudo tee -a /etc/repmgr/repmgr.conf
sudo su - postgres -c "repmgr -f /etc/repmgr/repmgr.conf master register"

echo -e "\n---- Prepare Failover Scripts ----"
cat <<EOF > ~/promote-server
#!/bin/bash
sudo su - postgres -c "repmgr -f /etc/repmgr/repmgr.conf standby promote"
EOF
cat <<EOF > ~/demote-server
#!/bin/bash
sudo service postgresql stop
sudo su - postgres -c "repmgr -f /etc/repmgr/repmgr.conf --force --rsync-only -h $SLAVE_IP -d repmgr -U repmgr --verbose standby clone"
sudo service postgresql restart
sudo su - postgres -c "repmgr -f /etc/repmgr/repmgr.conf --force standby register"
EOF
sudo chmod +x ~/promote-server
sudo chmod +x ~/demote-server

echo -e "\n---- Completed Master Configuration Successfully ----"
echo -e "\n---- Go & Start Configuring Slave Server ----"