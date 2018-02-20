#!/bin/bash
#####################################################################################################
# This script will install PgBouncer on your Ubuntu 16.04 server.
# Author: Mohamed Hammad
#----------------------------------------------------------------------------------------------------
# Make a new file:
# sudo nano 03-pgbouncer-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x 03-pgbouncer-install.sh
# Execute the script to install Postgres:
# sudo ./03-pgbouncer-install.sh
#######################################################################################################

MASTER_IP="192.168.1.10"
SLAVE_IP="192.168.1.11"
ODOO_DB_USER="odoo"
ODOO_DB_PASS="odoo"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt update
sudo apt upgrade -yV

#--------------------------------------------------
# Install PgBouncer
#--------------------------------------------------
echo -e "\n---- Install PgBouncer ----"
sudo apt install postgresql-client pgbouncer -yV

echo -e "\n---- Configure PgBouncer ----"
sudo sed -i "s/;\* = host=testserver/* = host=$MASTER_IP/g" /etc/pgbouncer/pgbouncer.ini
sudo sed -i "s/listen_addr = 127.0.0.1/listen_addr = 0.0.0.0/g" /etc/pgbouncer/pgbouncer.ini
sudo sed -i "s/auth_type = trust/auth_type = md5/g" /etc/pgbouncer/pgbouncer.ini
echo "admin_users = odoo" | sudo tee -a /etc/pgbouncer/pgbouncer.ini
echo "\"$ODOO_DB_USER\" \"$ODOO_DB_PASS\"" | sudo tee -a /etc/pgbouncer/userlist.txt
sudo service pgbouncer restart

echo -e "\n---- Prepare Failover Scripts ----"
cat <<EOF > ~/switch-node1
#!/bin/bash
sudo sed -i "s/\* = host=$SLAVE_IP/* = host=$MASTER_IP/g" /etc/pgbouncer/pgbouncer.ini
sudo service pgbouncer restart
EOF
cat <<EOF > ~/switch-node2
sudo sed -i "s/\* = host=$MASTER_IP/* = host=$SLAVE_IP/g" /etc/pgbouncer/pgbouncer.ini
sudo service pgbouncer restart
EOF
sudo chmod +x ~/switch-node1
sudo chmod +x ~/switch-node2

echo -e "\n---- Completed PgBouncer Installation Successfully ----"