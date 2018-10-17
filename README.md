# openshift-3.9-installation

yum -y install wget

wget https://raw.githubusercontent.com/PeterZong123/openshift-3.9-installation/master/vm-prerequisites.sh

wget https://raw.githubusercontent.com/PeterZong123/openshift-3.9-installation/master/vm-deployopenshift.sh

sh vm-prerequisites.sh
sh vm-deployopenshift.sh

-------------------------------------------------------

yum -y install wget

wget https://raw.githubusercontent.com/PeterZong123/openshift-3.9-installation/master/install-openshift.sh

sh install-openshift.sh
