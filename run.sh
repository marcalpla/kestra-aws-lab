#!/bin/bash
# Run the services on AWS
# Usage: ./run.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]

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

aws --region $AWS_REGION ecs update-service --cluster $NAME --service $NAME --desired-count 1 > /dev/null
aws --region $AWS_REGION ecs update-service --cluster $NAME --service ${NAME}Postgres --desired-count 1 > /dev/null

# Check if the SSH service exists
ssh_service_exists=$(aws --region $AWS_REGION ecs describe-services --cluster $NAME --services ${NAME}Ssh --query "services[0].serviceArn" --output text)

# If the SSH service exists, run it and get the public IP
if [ "$ssh_service_exists" != "None" ]; then
  aws --region $AWS_REGION ecs update-service --cluster $NAME --service ${NAME}Ssh --desired-count 1 > /dev/null

  # Try to get the ARN of the task of KestraSsh
  elapsed_time=0
  kestra_ssh_task_arn="None"
  while [ $elapsed_time -le 60 ]; do
    kestra_ssh_task_arn=$(aws --region $AWS_REGION ecs list-tasks --cluster $NAME --service-name ${NAME}Ssh --query "taskArns[0]" --output text)
    if [ "$kestra_ssh_task_arn" == "None" ]; then
      sleep 5
      elapsed_time=$((elapsed_time+5))
    else
      break
    fi
  done

  # Try to get the public IP of the task of KestraSsh
  public_ip="None"
  if [ "$kestra_ssh_task_arn" != "None" ]; then
    aws --region $AWS_REGION ecs wait tasks-running --cluster $NAME --tasks $kestra_ssh_task_arn
    network_interface_id=$(aws --region $AWS_REGION ecs describe-tasks --cluster $NAME --tasks $kestra_ssh_task_arn --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)
    if [ "$network_interface_id" != "None" ]; then
      public_ip=$(aws --region $AWS_REGION ec2 describe-network-interfaces --network-interface-ids $network_interface_id --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
    fi
  fi  
fi

# Try to get the ARN of the task of Kestra
elapsed_time=0
kestra_task_arn="None"
while [ $elapsed_time -le 60 ]; do
  kestra_task_arn=$(aws --region $AWS_REGION ecs list-tasks --cluster $NAME --service-name $NAME --query "taskArns[0]" --output text)
  if [ "$kestra_task_arn" == "None" ]; then
    sleep 5
    elapsed_time=$((elapsed_time+5))
  else
    break
  fi
done

# Try to get the private IP of the task of Kestra
private_ip="None"
if [ "$kestra_task_arn" != "None" ]; then
  aws --region $AWS_REGION ecs wait tasks-running --cluster $NAME --tasks $kestra_task_arn
  private_ip=$(aws --region $AWS_REGION ecs describe-tasks --cluster $NAME --tasks $kestra_task_arn --query "tasks[0].attachments[0].details[?name=='privateIPv4Address'].value" --output text)
fi

if [ "$private_ip" == "None" ]; then 
  private_ip="kestra_task_private_ip"
fi

# If the SSH service exists, print the SSH tunnel command and the URL
if [ "$ssh_service_exists" != "None" ]; then
  if [ "$public_ip" == "None" ]; then 
    public_ip="kestra_ssh_task_public_ip"
  fi
  echo "Execute the following command to start the SSH tunnel: ssh -N -L 8080:$private_ip:8080 -p 2222 SSH_TUNNEL_USER@$public_ip and then open http://localhost:8080 in your browser"
# If the SSH service does not exist, print the URL
else
  echo "Kestra web interface is available at http://$private_ip:8080"
fi