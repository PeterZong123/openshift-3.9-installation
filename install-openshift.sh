#!/bin/bash

## Default variables to use
export INTERACTIVE=${INTERACTIVE:="true"}
export DOMAIN=${DOMAIN:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}').nip.io"}
export USERNAME=${USERNAME:="$(whoami)"}
export PASSWORD=${PASSWORD:=password}
export SCRIPT_REPO=${SCRIPT_REPO:="https://raw.githubusercontent.com/PeterZong123/openshift-3.9-installation/master"}
export IP=${IP:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}')"}
export API_PORT=${API_PORT:="8443"}

## Make the script interactive to set the variables
if [ "$INTERACTIVE" = "true" ]; then
	read -rp "Domain to use: ($DOMAIN): " choice;
	if [ "$choice" != "" ] ; then
		export DOMAIN="$choice";
	fi

	read -rp "Username: ($USERNAME): " choice;
	if [ "$choice" != "" ] ; then
		export USERNAME="$choice";
	fi

	read -rp "Password: ($PASSWORD): " choice;
	if [ "$choice" != "" ] ; then
		export PASSWORD="$choice";
	fi

	read -rp "IP: ($IP): " choice;
	if [ "$choice" != "" ] ; then
		export IP="$choice";
	fi

	read -rp "API Port: ($API_PORT): " choice;
	if [ "$choice" != "" ] ; then
		export API_PORT="$choice";
	fi 

	echo

fi

echo "******"
echo "* Your domain is $DOMAIN "
echo "* Your IP is $IP "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "******"

# install updates
yum update -y

# install the following base packages
yum install -y  wget git zile nano net-tools docker-1.13.1\
				bind-utils iptables-services \
				bridge-utils bash-completion \
				kexec-tools sos psacct openssl-devel \
				httpd-tools NetworkManager \
				python-cryptography python2-pip python-devel  python-passlib \
				java-1.8.0-openjdk-headless "@Development Tools"

#install dnsmasq and config dns
#yum -y install dnsmasq
#nmcli dev show | grep IP4.DNS | sed -e 's/IP4.DNS\[1\]:/server=/g' | sed -e 's/ //g' > /etc/dnsmasq.d/origin-upstream-dns.conf

#cat > /etc/dbus-1/system.d/dnsmasq.conf <<EOF
#<!DOCTYPE busconfig PUBLIC
# "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
# "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
#<busconfig>
#        <policy user="root">
#                <allow own="uk.org.thekelleys.dnsmasq"/>
#                <allow send_destination="uk.org.thekelleys.dnsmasq"/>
#        </policy>
#        <policy context="default">
#                <deny own="uk.org.thekelleys.dnsmasq"/>
#                <deny send_destination="uk.org.thekelleys.dnsmasq"/>
#        </policy>
#</busconfig>
#EOF

#install epel
yum -y install epel-release

# Disable the EPEL repository globally so that is not accidentally used during later steps of the installation
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

systemctl | grep "NetworkManager.*running" 
if [ $? -eq 1 ]; then
	systemctl start NetworkManager
	systemctl enable NetworkManager
fi

# install the packages for Ansible
yum -y --enablerepo=epel install ansible pyOpenSSL

[ ! -d openshift-ansible ] && git clone https://github.com/PeterZong123/openshift-ansible.git

cd openshift-ansible && git fetch && git checkout release-3.9 && cd ..

cat <<EOD > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
${IP}		$(hostname) console console.${DOMAIN}  
EOD

systemctl restart docker
systemctl enable docker

if [ ! -f ~/.ssh/id_rsa ]; then
	ssh-keygen -q -f ~/.ssh/id_rsa -N ""
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	ssh -o StrictHostKeyChecking=no root@$IP "pwd" < /dev/null
fi

# pull images
#docker image pull openshift/node:v3.9.0


export METRICS="False"
export LOGGING="False"


curl -o inventory.download $SCRIPT_REPO/inventory.ini
envsubst < inventory.download > inventory.ini

ansible-playbook -i inventory.ini openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -i inventory.ini openshift-ansible/playbooks/deploy_cluster.yml

htpasswd -b /etc/origin/master/htpasswd ${USERNAME} ${PASSWORD}
oc adm policy add-cluster-role-to-user cluster-admin ${USERNAME}

systemctl restart origin-master-api

echo "******"
echo "* Your console is https://console.$DOMAIN:$API_PORT"
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "*"
echo "* Login using:"
echo "*"
echo "$ oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:$API_PORT/"
echo "******"

oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:$API_PORT/
