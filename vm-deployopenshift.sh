#!/bin/bash

# default variables to use
export INTERACTIVE=${INTERACTIVE:="true"}
export DOMAIN=${DOMAIN:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}').nip.io"}
export IP=${IP:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}')"}
export API_PORT=${API_PORT:="8443"}
export USERNAME=${USERNAME:="$(whoami)"}
export PASSWORD=${PASSWORD:=password}
export METRICS=${METRICS:="False"}
export LOGGING=${LOGGING:="False"}

# make the script interactive to set the variables
if [ "$INTERACTIVE" = "true" ]; then
	read -rp "Domain to use: ($DOMAIN): " choice;
	if [ "$choice" != "" ] ; then
		export DOMAIN="$choice";
	fi
	
	read -rp "IP: ($IP): " choice;
	if [ "$choice" != "" ] ; then
		export IP="$choice";
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
echo "* Your port is $API_PORT "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "******"

# modify hosts
cat <<EOD > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
${IP}		$(hostname) console console.${DOMAIN}  
EOD

# generate ssh key
if [ ! -f ~/.ssh/id_rsa ]; then
	ssh-keygen -q -f ~/.ssh/id_rsa -N ""
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	ssh -o StrictHostKeyChecking=no root@$IP "pwd" < /dev/null
fi

# create inventory.ini
cat > inventory.ini <<EOF
[OSEv3:children]
masters
nodes
etcd

[masters]
${IP} openshift_ip=${IP} openshift_schedulable=true 

[etcd]
${IP} openshift_ip=${IP}

[nodes]
${IP} openshift_ip=${IP} openshift_schedulable=true openshift_node_labels="{'region': 'infra', 'zone': 'default'}"

[OSEv3:vars]
ansible_ssh_user=root
enable_excluders=False
enable_docker_excluder=False
ansible_service_broker_install=False

containerized=True
os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'
openshift_disable_check=disk_availability,docker_storage,memory_availability,docker_image_availability

openshift_node_kubelet_args={'pods-per-core': ['50']}

deployment_type=origin
openshift_deployment_type=origin


openshift_release=v3.9
openshift_pkg_version=-3.9.0
openshift_image_tag=v3.9.0
openshift_service_catalog_image_version=v3.9
template_service_broker_image_version=v3.9
template_service_broker_selector={"region":"infra"}
openshift_metrics_image_version="v3.9"
openshift_logging_image_version="v3.9.0"
openshift_logging_elasticsearch_proxy_image_version="v1.0.0"
logging_elasticsearch_rollout_override=false
osm_use_cockpit=false
openshift_install_examples=true

openshift_metrics_install_metrics=${METRICS}
openshift_logging_install_logging=${LOGGING}

openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]

openshift_public_hostname=console.${DOMAIN}
openshift_master_default_subdomain=apps.${DOMAIN}
openshift_master_api_port=${API_PORT}
openshift_master_console_port=${API_PORT}
EOF

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
