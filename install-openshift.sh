#!/bin/bash

# default variables to use
export INTERACTIVE=${INTERACTIVE:="true"}
export DOMAIN=${DOMAIN:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}').nip.io"}
export IP=${IP:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}')"}
export API_PORT=${API_PORT:="8443"}
export USERNAME=${USERNAME:="$(whoami)"}
export PASSWORD=${PASSWORD:=password}
export SCRIPT_REPO=${SCRIPT_REPO:="https://raw.githubusercontent.com/PeterZong123/openshift-3.9-installation/master"}
export ANSIBLE_PLAYBOOKS_REPO=${ANSIBLE_PLAYBOOKS_REPO:="https://github.com/PeterZong123/openshift-ansible.git"}
export METRICS=${METRICS:="False"}
export LOGGING=${LOGGING:="False"}

# make the script interactive to set the variables
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

	read -rp "Ansible Playbooks Repo: ($ANSIBLE_PLAYBOOKS_REPO): " choice;
	if [ "$choice" != "" ] ; then
		export ANSIBLE_PLAYBOOKS_REPO="$choice";
	fi 

	read -rp "Enable Metrics: ($METRICS): " choice;
	if [ "$choice" != "" ] ; then
		export METRICS="$choice";
	fi 

	read -rp "Enable Logging: ($LOGGING): " choice;
	if [ "$choice" != "" ] ; then
		export LOGGING="$choice";
	fi 

	echo
fi

echo "******"
echo "* Your domain is $DOMAIN "
echo "* Your IP is $IP "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "* Ansible Playbooks Repo is $ANSIBLE_PLAYBOOKS_REPO "
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

# install epel
yum -y install epel-release

# disable the EPEL repository globally so that is not accidentally used during later steps of the installation
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

# start NetworkManager
systemctl | grep "NetworkManager.*running" 
if [ $? -eq 1 ]; then
	systemctl start NetworkManager
	systemctl enable NetworkManager
fi

# install the packages for Ansible
yum -y --enablerepo=epel install pyOpenSSL

#yum -y erase ansible
#wget http://cbs.centos.org/kojifiles/packages/ansible/2.5.3/1.el7/noarch/ansible-2.5.3-1.el7.noarch.rpm
#yum -y install ansible-2.5.3-1.el7.noarch.rpm

wget https://releases.ansible.com/ansible/ansible-2.5.5.tar.gz
tar xvzf ansible-2.5.5.tar.gz
cd ansible-2.5.5/
python setup.py install
cd ..

# clone openshift ansible playbooks
[ ! -d openshift-ansible ] && git clone $ANSIBLE_PLAYBOOKS_REPO

cd openshift-ansible && git fetch && git checkout release-3.9 && cd ..

# modify hosts
cat <<EOD > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
${IP}		$(hostname) console console.${DOMAIN}  
EOD

# restart docker
systemctl restart docker
systemctl enable docker

# generate ssh key
if [ ! -f ~/.ssh/id_rsa ]; then
	ssh-keygen -q -f ~/.ssh/id_rsa -N ""
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	ssh -o StrictHostKeyChecking=no root@$IP "pwd" < /dev/null
fi

# pull images
docker image pull cockpit/kubernetes:latest
docker image pull registry.fedoraproject.org/latest/etcd:latest
docker image pull openshift/node:v3.9.0
docker image pull openshift/origin-web-console:v3.9.0
docker image pull openshift/origin-docker-registry:v3.9.0
docker image pull openshift/openvswitch:v3.9.0
docker image pull openshift/origin-haproxy-router:v3.9.0
docker image pull openshift/origin-deployer:v3.9.0
docker image pull openshift/origin:v3.9.0
docker image pull openshift/origin-template-service-broker:v3.9.0
docker image pull openshift/origin-pod:v3.9.0
docker image pull openshift/origin-service-catalog:3.9
docker image pull openshift/origin-metrics-cassandra:v3.9
docker image pull openshift/origin-metrics-hawkular-metrics:v3.9
docker image pull openshift/origin-metrics-heapster:v3.9

# download inventory.ini
curl -o inventory.download $SCRIPT_REPO/inventory.ini
envsubst < inventory.download > inventory.ini

# run playbooks to deploy openshift
ansible-playbook -i inventory.ini openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -i inventory.ini openshift-ansible/playbooks/deploy_cluster.yml

# post-deployment
htpasswd -b /etc/origin/master/htpasswd ${USERNAME} ${PASSWORD}
oc adm policy add-cluster-role-to-user cluster-admin ${USERNAME}

systemctl restart origin-master-api

sleep 5

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
