#!/bin/bash
# Stop the services on AWS
# Usage: ./deploy.sh -r AWS_REGION -n NAME [-p AWS_PROFILE]

# Debug mode (uncomment to enable)
# set -ux

set -eo pipefail

while getopts ":r:n:p:" opt; do
  case $opt in
    r) AWS_REGION=$OPTARG ;;
    n) NAME=$OPTARG ;;
    p) AWS_PROFILE=$OPTARG ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

# Check if the required parameters are set
if [ -z "$AWS_REGION" ] || [ -z "$NAME" ]; then
  echo "Usage: ./deploy.sh -r AWS_REGION -n NAME [-p AWS_PROFILE]"
  exit 1
fi

aws --region $AWS_REGION ecs update-service --cluster $NAME --service $NAME --desired-count 0 > /dev/null
aws --region $AWS_REGION ecs update-service --cluster $NAME --service ${NAME}Postgres --desired-count 0 > /dev/null
aws --region $AWS_REGION ecs update-service --cluster $NAME --service ${NAME}Ssh --desired-count 0 > /dev/null
