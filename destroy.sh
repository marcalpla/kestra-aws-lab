#!/bin/bash
# Destroy the stack in AWS
# Usage: ./destroy.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]

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

aws --region $AWS_REGION cloudformation delete-stack --stack-name $NAME
aws --region $AWS_REGION cloudformation wait stack-delete-complete --stack-name $NAME || true