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

if [ -z $DEBUGMODE ];
then
export DEBUGMODE=0
fi

if [ -z $DRYMODE ];
then
export DRYMODE=0
fi

if [ -z $EXEC_PATH ];then
export EXEC_PATH=`pwd`
export EXEC_PATH=$EXEC_PATH/tmp
fi

while true;
do
sleep 10s
echo "Using execute path as $EXEC_PATH"
if [ -f $EXEC_PATH ];
then
echo ""
else
mkdir -p $EXEC_PATH
if [ $? -ne 0 ]; then
echo "error creating directy $EXEC_PATH"
exit 1
fi
fi

# creating necessary files
touch $EXEC_PATH/faulty1.txt
touch $EXEC_PATH/faulty2.txt
touch $EXEC_PATH/faulty.txt

projectcount=`oc get projects | wc -l`

echo "Got access to $projectcount projects"

# find the faulty nodes
echo "finding faulty nodes"
oc adm top nodes -l node-role.kubernetes.io/compute=true | tail -n +2 | awk '{if($3>0)print$1}' > $EXEC_PATH/faulty1.txt
cat $EXEC_PATH/faulty1.txt
echo ""

# waiting for 15 min to check the load is above threshold
sleep 10s

# checking again for the faulty nodes
oc adm top nodes -l node-role.kubernetes.io/compute=true | tail -n +2 | awk '{if($3>0)print$1}' > $EXEC_PATH/faulty2.txt
echo "finding new faulty nodes"
cat $EXEC_PATH/faulty2.txt
echo ""

# validate the nodes before going execution
grep -Fxf $EXEC_PATH/faulty1.txt $EXEC_PATH/faulty2.txt > $EXEC_PATH/faulty.txt
echo "Faulty Nodes"
cat $EXEC_PATH/faulty.txt
echo ""

# check if faulty nodes are available
if [ -s $EXEC_PATH/faulty.txt ]; then #checks if file size is greater than 0
echo "Faulty Nodes found"
cat $EXEC_PATH/faulty.txt
echo ""

# checking for DRYMODE
if [ $DRYMODE == 0 ]; then
echo "Node cleanup taking place"

echo "Removing Dead, Exited containers, Dangling and unused images"
for ip_addr in $(cat $EXEC_PATH/faulty.txt); do
ssh ${ip_addr} "bash -s" < script.sh
done

echo "Make faulty nodes unschedulable"
export filename="$EXEC_PATH/faulty.txt"

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
for ip_addr1 in $(cat $EXEC_PATH/faulty.txt); do
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
for ip_addr2 in $(cat $EXEC_PATH/faulty.txt); do
ssh ${ip_addr2} "bash -s" < docker-install.sh
done
else
echo "Error in Docker installation and configuration"
exit 1
fi

echo "Make nodes schedulable"
export filename="$EXEC_PATH/faulty.txt"

while read node3
do
echo ${node3}
oc adm manage-node ${node3} --schedulable=true
done < ${filename}

else
echo "Am in debug mode, exiting the service" #DRYMODE execution
fi

echo ""

else
echo "No Faulty nodes found"
fi

done
