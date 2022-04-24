#!/bin/bash
clear
echo "checking for oc client in path"
echo "printing all variables to screen"
env
echo ""
echo ""
sleep 1
which oc 2> /dev/null
if [ $? -ne 0 ]; then
    echo "oc binary not found, so terminating"
    exit 1
fi

oc whoami
if [ $? -ne 0 ]; then 
    echo "Not logged into any cluster, please login into the cluster"
    exit 1
fi

projectcount=`oc get projects | wc -l`
echo "Got access to $projectcount projects"
#echo "starting processing the ep with max retain count as $MAXCOUNT"

# find the faulty nodes
 oc adm top nodes -l node-role.kubernetes.io/compute=true | tail -n +2 | awk '{if($1>0)print$1}' > faulty.txt

# validate the nodes before going execution

# check if faulty nodes are available
if [ -s faulty.txt ]; then #checks if file size is greater than 0
        echo "Faulty Nodes found"
        cat faulty.txt
else
        echo "No Faulty nodes found"
        exit 1
fi
echo ""

echo "Removing Dead, Exited containers, Dangling and unused images"
for ip_addr in $(cat faulty.txt); do
     ssh ${ip_addr} "bash -s" < script.sh
done

echo "Make faulty nodes unschedulable"
export filename="faulty.txt"

while read node
do
  echo ${node}
  oc adm manage-node ${node} --schedulable=false
done < ${filename}

echo "Drain the faulty nodes"

while read node1
do
  echo ${node1}
  oc adm drain ${node1} --ignore-daemonsets --timeout=60s
done < ${filename}

if [ $? == 0 ]; then
    echo "Nodes is sucessfully drained"
    echo "Clean up docker volumes and uninstall docker service"
    for ip_addr1 in $(cat faulty.txt); do
      ssh ${ip_addr1} "bash -s" < docker-prune.sh
    done
else
    echo "Error in managing nodes"
    exit 1
fi

echo "sleep for 120 sec"
sleep 2

if [ $? == 0 ]; then
    echo "Installing and configuring the Docker in faulty nodes"
    for ip_addr2 in $(cat faulty.txt); do
      ssh ${ip_addr2} "bash -s" < docker-install.sh
    done
else
    echo "Error in Docker installation and configuration"
    exit 1
fi

echo "Make nodes schedulable"
export filename="faulty.txt"

while read node3
do
  echo ${node3}
  oc adm manage-node ${node3} --schedulable=true
done < ${filename}