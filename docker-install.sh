#!/bin/bash
echo "Install and configure Docker in faulty nodes"
sudo yum install docker -y
echo ""

echo "Exclude docker from updates: sticky version"
sudo atomic-openshift-docker-excluder exclude

if [ $? == 0 ]; then
    echo "Remove the docker cofig file"
    sudo rm -vf /root/.docker/config.json
    echo ''
    echo "Configure Docker storage driver"
    sudo sed -i 's/STORAGE_DRIVER=.*$/STORAGE_DRIVER=devicemapper/' /etc/sysconfig/docker-storage-setup
    echo ""
    echo "Configure Docker storage"
    sudo sed -n -e '/^VG=/!p' -e '$aVG=docker' /etc/sysconfig/docker-storage-setup
    echo ''
    echo "Configure storage data size"
    sudo sed -n -e '/^DATA_SIZE=/!p' -e '$aDATA_SIZE=80%FREE' /etc/sysconfig/docker-storage-setup
    echo ''
    echo "Setup docker storage script"
    sudo docker-storage-setup
    echo ''
    echo "restart the docker service"
    sudo systemctl restart docker
    echo ''
    echo "restart the atomic service"
    sudo systemctl restart atomic-openshift-node
    echo ''
else
    echo "Error in Excluding the docker service"
    exit 1
fi
echo ""

echo "wait for 30 sec"
sleep 30

# start the ocp services

echo "Start and enable the node services"
sudo systemctl start atomic-openshift-node
sudo systemctl enable atomic-openshift-node
echo ""

echo "sleep for 30 sec"
sleep 30

echo "Check openshift process and status"
STATUS="$(sudo systemctl is-active atomic-openshift-node)"
if [ "${STATUS}" == "active" ]; then
    echo "atomic-openshift-node is in Active state"
else
    echo "atomic-openshift-node is not running"
    exit 1
fi
