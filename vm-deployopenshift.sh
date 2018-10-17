#!/bin/bash

# default variables to use
export INTERACTIVE=${INTERACTIVE:="true"}
export DOMAIN=${DOMAIN:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}').nip.io"}
export API_PORT=${API_PORT:="8443"}
export USERNAME=${USERNAME:="$(whoami)"}
export PASSWORD=${PASSWORD:=password}

# make the script interactive to set the variables
if [ "$INTERACTIVE" = "true" ]; then
	read -rp "Domain to use: ($DOMAIN): " choice;
	if [ "$choice" != "" ] ; then
		export DOMAIN="$choice";
	fi

	read -rp "API Port: ($API_PORT): " choice;
	if [ "$choice" != "" ] ; then
		export API_PORT="$choice";
	fi 
  
	read -rp "Username: ($USERNAME): " choice;
	if [ "$choice" != "" ] ; then
		export USERNAME="$choice";
	fi

	read -rp "Password: ($PASSWORD): " choice;
	if [ "$choice" != "" ] ; then
		export PASSWORD="$choice";
	fi

	echo
fi

echo "******"
echo "* Your domain is $DOMAIN "
echo "* Your port is $API_PORT "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "******"

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
