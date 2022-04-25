#!/bin/bash
# Remove the Non Running containers
PRUNE_IDS=$(sudo docker ps -a | awk '/Exited|Dead|Created/ {print $1}')
if [ -n "$PRUNE_IDS" ]; then
  docker rm $PRUNE_IDS > /dev/null 2>&1
  echo 'Containers removed' $PRUNE_IDS
else
  echo 'No non running containers present in the nodes'
fi

# Remove dangling images
IMAGE_IDS=$(sudo docker images -f "dangling=true" -q)

if [ -n "$IMAGE_IDS" ]; then
  docker rmi -f $IMAGE_IDS > /dev/null 2>&1
  echo 'Images removed' $IMAGE_IDS
else
  echo "No dandling images found"
fi


# Remove Non Running Docker images
CONTAINER_IDS=$(sudo docker images | awk '{print $3}')

if [ -n "$CONTAINER_IDS" ]; then
  docker rmi -f $CONTAINER_IDS > /dev/null 2>&1
  echo 'Removed unused images'
else
  echo 'No non Running Docker images found'
fi
