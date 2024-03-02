#!/bin/bash
#Provided by adam@wittsgarage.com
#@wittyphantom333

function pause(){
   read -p "$*"
}

echo "=======================">>setup.log 2>>error.log
date>>setup.log 2>>error.log
echo "=======================">>setup.log 2>>error.log

echo "Detecting IP Address"
IPADDY="$(hostname -I)"
echo "Detected IP Address is $IPADDY"

SERVERNAME=$IPADDY
SERVERALIAS=$IPADDY

echo "Installind PreReqs"
dnf install nano git wget epel-release -y && dnf update

echo "Setting Up Repositories"
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch >>setup.log 2>>error.log
rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-5.0-repository_latest.rpm >>setup.log 2>>error.log

echo "[elasticsearch-7.10.2]
name=Elasticsearch repository for 7.10.2 packages
baseurl=https://artifacts.elastic.co/packages/oss-7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md" > /etc/yum.repos.d/elasticsearch.repo

echo "[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8Server/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc" > /etc/yum.repos.d/mongodb-org.repo

echo "Updating System"
dnf update >>setup.log 2>>error.log

echo "Installing Elasticsearch"
dnf install -y elasticsearch-oss >>setup.log 2>>error.log
sed -i -e 's|# cluster.name: my-application|cluster.name: graylog|' /etc/elasticsearch/elasticsearch.yml
systemctl daemon-reload >>setup.log 2>>error.log
systemctl enable elasticsearch.service >>setup.log 2>>error.log
systemctl restart elasticsearch.service >>setup.log 2>>error.log

echo "Installing MongoDB"
dnf install -y mongodb-org >>setup.log 2>>error.log
systemctl start mongod >>setup.log 2>>error.log
systemctl enable mongod >>setup.log 2>>error.log

echo "Installing Graylog 5"
dnf -y install pwgen graylog-server >>setup.log 2>>error.log

echo -n "Enter a password to use for the admin account to login to the Graylog5 webUI: "
read adminpass
echo "You entered $adminpass (MAKE SURE TO NOT FORGET THIS PASSWORD!)"
pause 'Press [Enter] key to continue...'

pass_secret=$(pwgen -s 96)
sed -i -e "s|password_secret =|password_secret = $pass_secret|" /etc/graylog/server/server.conf

admin_pass_hash=$(echo -n $adminpass|sha256sum|awk '{print $1}')
sed -i -e "s|root_password_sha2 =|root_password_sha2 = $admin_pass_hash|" /etc/graylog/server/server.conf

#sed -i -e "s|rest_listen_uri = http://127.0.0.1:9000/api/|rest_listen_uri = http://'$IPADDY':12900/|" /etc/graylog/server/server.conf
#sed -i -e "s|#web_listen_uri = http://127.0.0.1:9000/|web_listen_uri = http://'$IPADDY':9000/|" /etc/graylog/server/server.conf
sed -i -e "s|#http_bind_address = 127.0.0.1:9000|http_bind_address = http://'$IPADDY':9000/|" /etc/graylog/server/server.conf

sudo systemctl daemon-reload >>setup.log 2>>error.log
sudo systemctl enable graylog-server.service >>setup.log 2>>error.log
sudo systemctl start graylog-server.service >>setup.log 2>>error.log

echo "Adding Firewall Rules"
firewall-cmd --permanent --add-port=9000/tcp >>setup.log 2>>error.log
firewall-cmd --reload >>setup.log 2>>error.log
sed -i -e "s|SELINUX=enforcing|SELINUX=disabled" /etc/selinux/config
setenforce 0

# All Done
echo "Installation has completed!!"
echo "Browse to IP address of this Graylog5 Server Used for Installation"
echo "IP Address detected from system is $IPADDY"
echo "Browse to http://'$IPADDY':9000"
echo "Login with username: admin"
echo "Login with password: $adminpass"
