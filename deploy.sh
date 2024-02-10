#!/bin/bash
# Deploy the stack to AWS
# Usage: ./deploy.sh -r AWS_REGION -n NAME -u SSH_TUNNEL_USER -p SSH_TUNNEL_PASSWORD [-a AWS_PROFILE]

# Debug mode (uncomment to enable)
# set -ux

set -eo pipefail

while getopts ":r:n:u:p:a:" opt; do
  case $opt in
    r) AWS_REGION=$OPTARG ;;
    n) NAME=$OPTARG ;;
    u) SSH_TUNNEL_USER=$OPTARG ;;
    p) SSH_TUNNEL_PASSWORD=$OPTARG ;;
    a) AWS_PROFILE=$OPTARG ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
  esac
done

# Check if the required parameters are set
if [ -z "$AWS_REGION" ] || [ -z "$NAME" ] || [ -z "$SSH_TUNNEL_USER" ] || [ -z "$SSH_TUNNEL_PASSWORD" ]; then
  echo "Usage: ./deploy.sh -r AWS_REGION -n NAME -u SSH_TUNNEL_USER -p SSH_TUNNEL_PASSWORD [-a AWS_PROFILE]"
  exit 1
fi

# Check if the stack already exists
if aws --region $AWS_REGION cloudformation describe-stacks --stack-name $NAME > /dev/null 2>&1; then
  read -p "Stack $NAME already exists. Do you want to update it? (y/n): " answer
  if [[ $answer == [Yy] ]]; then
    aws --region $AWS_REGION cloudformation update-stack --stack-name $NAME --template-body file://./template.yaml --capabilities CAPABILITY_NAMED_IAM \
      --parameters "ParameterKey=Name, ParameterValue=$NAME" \
                  "ParameterKey=SshTunnelUser, ParameterValue=$SSH_TUNNEL_USER" \
                  "ParameterKey=SshTunnelPassword, ParameterValue=$SSH_TUNNEL_PASSWORD"
    aws --region $AWS_REGION cloudformation wait stack-update-complete --stack-name $NAME || true
    aws --region $AWS_REGION cloudformation describe-stacks --stack-name $NAME --query "Stacks[0].StackStatus"
  fi
else
  aws --region $AWS_REGION cloudformation create-stack --stack-name $NAME --template-body file://./template.yaml --capabilities CAPABILITY_NAMED_IAM \
    --parameters "ParameterKey=Name, ParameterValue=$NAME" \
                "ParameterKey=SshTunnelUser, ParameterValue=$SSH_TUNNEL_USER" \
                "ParameterKey=SshTunnelPassword, ParameterValue=$SSH_TUNNEL_PASSWORD"
  aws --region $AWS_REGION cloudformation wait stack-create-complete --stack-name $NAME || true
  aws --region $AWS_REGION cloudformation describe-stacks --stack-name $NAME --query "Stacks[0].StackStatus"
fi