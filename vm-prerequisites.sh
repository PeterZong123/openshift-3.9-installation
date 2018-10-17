#!/bin/bash

# default variables to use
export INTERACTIVE=${INTERACTIVE:="true"}
export ANSIBLE_PLAYBOOKS_REPO=${ANSIBLE_PLAYBOOKS_REPO:="https://github.com/PeterZong123/openshift-ansible.git"}

# make the script interactive to set the variables
if [ "$INTERACTIVE" = "true" ]; then
	read -rp "Ansible Playbooks Repo: ($ANSIBLE_PLAYBOOKS_REPO): " choice;
	if [ "$choice" != "" ] ; then
		export ANSIBLE_PLAYBOOKS_REPO="$choice";
	fi 

	echo
fi

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

# install ansible 2.5.5
wget https://releases.ansible.com/ansible/ansible-2.5.5.tar.gz
tar xvzf ansible-2.5.5.tar.gz
cd ansible-2.5.5/
python setup.py install
cd ..

# clone openshift ansible playbooks
[ ! -d openshift-ansible ] && git clone $ANSIBLE_PLAYBOOKS_REPO

cd openshift-ansible && git fetch && git checkout release-3.9 && cd ..

# restart docker
systemctl restart docker
systemctl enable docker

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
