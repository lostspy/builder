#!/bin/bash
echo "Ensure docker is installed"
sudo rpm -q docker
echo ''

echo "Check docker process and stop"
STATUS="$(sudo systemctl is-active docker)"
if [ "${STATUS}" = "active" ]; then
    echo "Docker is in Active state"
    echo "Stopping the Docker service"
    sudo systemctl stop docker
else
    echo " Docker is not running "
    exit 1
fi

echo "Unmount docker volumes"
sudo umount -f /var/lib/docker/containers
if [ $? -ne 0 ]; then
    echo "Could not unmount partition" >&2
fi
sudo umount -f /var/lib/docker/devicemapper
if [ $? -ne 0 ]; then
    echo "Could not unmount partition" >&2
fi
sudo umount -f /var/lib/docker/overlay2
if [ $? -ne 0 ]; then
    echo "Could not unmount partition" >&2
fi
sudo umount -f /var/lib/docker/openshift.local.volumes
if [ $? -ne 0 ]; then
    echo "Could not unmount partition" >&2
fi

echo "wipe out the /var/lib/docker directory"
sudo rm -rvf /var/lib/docker/*
if [ $? -ne 0 ]; then
    echo "Unable to wipe all data inside docker directory" >&2
    exit 1
fi

echo "reset docker storage"
sudo docker-storage-setup --reset
if [ $? == 0 ]; then
    echo "Uninstall docker service"
    sudo yum remove docker -y
else
    echo "Error in resetting docker storage"
fi

echo "Rebooting the target node"
sudo systemctl reboot -i