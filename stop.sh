#!/bin/bash
# Stop the services on AWS
# Usage: ./stop.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]

# Debug mode (uncomment to enable)
# set -ux

set -eo pipefail

while getopts ":r:n:a:" opt; do
  case $opt in
    r) AWS_REGION=$OPTARG ;;
    n) NAME=$OPTARG ;;
    a) export AWS_PROFILE=$OPTARG ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
  esac
done

# Check if the required parameters are set
if [ -z "$AWS_REGION" ] || [ -z "$NAME" ]; then
  echo "Usage: ./deploy.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]"
  exit 1
fi

aws --region $AWS_REGION ecs update-service --cluster $NAME --service $NAME --desired-count 0 > /dev/null
aws --region $AWS_REGION ecs update-service --cluster $NAME --service ${NAME}Postgres --desired-count 0 > /dev/null

# Check if the SSH service exists and stop it
ssh_service_exists=$(aws --region $AWS_REGION ecs describe-services --cluster $NAME --services ${NAME}Ssh --query "services[0].serviceArn" --output text)
if [ "$ssh_service_exists" != "None" ]; then
  aws --region $AWS_REGION ecs update-service --cluster $NAME --service ${NAME}Ssh --desired-count 0 > /dev/null
fi

