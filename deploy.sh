#!/bin/bash
# Deploy the stack to AWS
# Usage: ./deploy.sh -r AWS_REGION -n NAME -t TEMPLATE_FILE [-c] [-b SUBNET_ID -v VPC_ID] [-u SSH_TUNNEL_USER -p SSH_TUNNEL_PASSWORD] [-I PRIVATE_IP_ADDRESSES] [-K KEY_PAIR_NAME] [-x EBS_VOLUME_IDS] [-y EFS_VOLUME_IDS] [-V] [-T TAGS] [-i KESTRA_IMAGE (default: kestra/kestra:latest-full)] [-e KESTRA_IMAGE_REPOSITORY_USER -f KESTRA_IMAGE_REPOSITORY_PASSWORD] [-k KESTRA_CONFIG_FILE (default: default.yaml)] [-s KESTRA_INIT_SCRIPT (default: default.sh)] [-U DATABASE_USER (default: kestra)] [-P DATABASE_PASSWORD (default: random generated password)] [-a AWS_PROFILE]
# Note: -t flag is the name of the file in the template directory
# Note: -c flag creates a network. -b and -v are required if not creating a network
# Note: -u and -p must be used together if creating a network
# Note: -I flag is a comma-separated list of private IP addresses
# Note: -K flag is the name of the key pair to use for the EC2 instances
# Note: Use commas to separate multiple EBS (-x) and EFS (-y) volume IDs. Example: -x vol-123,vol-456
# Note: -V flag is used to indicate that the stack should create a Vault 
# Note: -T flag is a comma-separated list of tags in the format Key=Value
# Note: -k and -s flags are the names of the files in the config and init directories, respectively
# Note: -U and -P flags are the username and password to use for the Postgres database

# Debug mode (uncomment to enable)
# set -ux

set -eo pipefail

CREATE_NETWORK=false
PRIVATE_IP_ADDRESSES=()
EBS_VOLUME_IDS=()
EFS_VOLUME_IDS=()
CREATE_VAULT=false
TAGS=()
KESTRA_IMAGE="kestra/kestra:latest-full"
KESTRA_IMAGE_REPOSITORY_USER=""
KESTRA_IMAGE_REPOSITORY_PASSWORD=""
KESTRA_CONFIG_FILE="config/default.yaml"
DATABASE_USER="kestra"
DATABASE_PASSWORD=$(openssl rand -base64 12)

while getopts ":r:n:t:cb:v:u:p:I:K:x:y:VT:i:e:f:k:s:U:P:a:" opt; do
  case $opt in
    r) AWS_REGION=$OPTARG ;;
    n) NAME=$OPTARG ;;
    t) TEMPLATE_FILE="template/$OPTARG" ;;
    c) CREATE_NETWORK=true ;;
    b) SUBNET_ID=$OPTARG ;;
    v) VPC_ID=$OPTARG ;;    
    u) SSH_TUNNEL_USER=$OPTARG ;;
    p) SSH_TUNNEL_PASSWORD=$OPTARG ;;
    I) IFS=',' read -r -a PRIVATE_IP_ADDRESSES <<< "$OPTARG" ;;
    K) KEY_PAIR_NAME=$OPTARG ;;
    x) IFS=',' read -r -a EBS_VOLUME_IDS <<< "$OPTARG" ;;
    y) IFS=',' read -r -a EFS_VOLUME_IDS <<< "$OPTARG" ;;
    V) CREATE_VAULT=true ;;
    T) IFS=',' read -r -a TAGS <<< "$OPTARG" ;;
    i) KESTRA_IMAGE=$OPTARG ;;
    e) KESTRA_IMAGE_REPOSITORY_USER=$OPTARG ;;
    f) KESTRA_IMAGE_REPOSITORY_PASSWORD=$OPTARG ;;    
    k) KESTRA_CONFIG_FILE="config/$OPTARG" ;;
    s) KESTRA_INIT_SCRIPT="init/$OPTARG" ;;
    U) DATABASE_USER=$OPTARG ;;
    P) DATABASE_PASSWORD=$OPTARG ;;
    a) export AWS_PROFILE=$OPTARG ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
  esac
done

# Check if the create network flag is set
if [[ $CREATE_NETWORK = true ]]; then
  if [ -z "$SSH_TUNNEL_USER" ] || [ -z "$SSH_TUNNEL_PASSWORD" ]; then
    echo "Creating a network requires -u SSH_TUNNEL_USER and -p SSH_TUNNEL_PASSWORD"
    exit 1
  fi
else
  if [ -z "$SUBNET_ID" ] || [ -z "$VPC_ID" ]; then
    echo "Not creating a network requires -b SUBNET_ID and -v VPC_ID"
    exit 1
  fi
fi

# Check if the SSH tunnel user and password are set together
if [ -n "$SSH_TUNNEL_USER" ] && [ -z "$SSH_TUNNEL_PASSWORD" ] || [ -z "$SSH_TUNNEL_USER" ] && [ -n "$SSH_TUNNEL_PASSWORD" ]; then
  echo "Both SSH tunnel user and password are required together"
  exit 1
fi

# Check if the Kestra image repository user and password are set together
if [[ -n $KESTRA_IMAGE_REPOSITORY_USER && -z $KESTRA_IMAGE_REPOSITORY_PASSWORD ]] || [[ -z $KESTRA_IMAGE_REPOSITORY_USER && -n $KESTRA_IMAGE_REPOSITORY_PASSWORD ]]; then
  echo "Both Kestra image repository user and password are required together"
  exit 1
fi

# Check if the required parameters are set
if [ -z "$AWS_REGION" ] || [ -z "$NAME" ] || [ -z "$TEMPLATE_FILE" ]; then
  echo "Usage: ./deploy.sh -r AWS_REGION -n NAME -t TEMPLATE_FILE [-c] [-b SUBNET_ID -v VPC_ID] [-u SSH_TUNNEL_USER -p SSH_TUNNEL_PASSWORD] [-I PRIVATE_IP_ADDRESSES] [-x EBS_VOLUME_IDS] [-y EFS_VOLUME_IDS] [-V] [-T TAG] [-i KESTRA_IMAGE (default: kestra/kestra:latest-full)] [-e KESTRA_IMAGE_REPOSITORY_USER -f KESTRA_IMAGE_REPOSITORY_PASSWORD] [-k KESTRA_CONFIG_FILE (default: default.yaml)] [-s KESTRA_INIT_SCRIPT (default: default.sh)] [-U DATABASE_USER (default: kestra)] [-P DATABASE_PASSWORD (default: random generated password)] [-a AWS_PROFILE]"
  exit 1
fi

# Check if the stack already exists
if aws --region $AWS_REGION cloudformation describe-stacks --stack-name $NAME > /dev/null 2>&1; then
  echo "Stack $NAME already exists"
  exit 1
fi

# Initialize the parameters array
params=(
  "ParameterKey=Name,ParameterValue=$NAME"
  "ParameterKey=CreateNetwork,ParameterValue=$(echo $CREATE_NETWORK)"
  "ParameterKey=KestraImage,ParameterValue=$KESTRA_IMAGE"
  "ParameterKey=DatabaseUser,ParameterValue=$DATABASE_USER"
  "ParameterKey=DatabasePassword,ParameterValue=$DATABASE_PASSWORD"
)

# Add existing network parameters if not creating a network
if [[ $CREATE_NETWORK = false ]]; then
  params+=(
    "ParameterKey=ExistingSubnetId,ParameterValue=$SUBNET_ID"
    "ParameterKey=ExistingVpcId,ParameterValue=$VPC_ID"
  )
fi

# Add SSH tunnel user and password parameters if provided
if [[ -n $SSH_TUNNEL_USER && -n $SSH_TUNNEL_PASSWORD ]]; then
  params+=(
    "ParameterKey=SshTunnelUser,ParameterValue=$SSH_TUNNEL_USER"
    "ParameterKey=SshTunnelPassword,ParameterValue=$SSH_TUNNEL_PASSWORD"
  )
fi

# Add private IP addresses parameters if provided
if [ ${#PRIVATE_IP_ADDRESSES[@]} -ne 0 ]; then
  for i in "${!PRIVATE_IP_ADDRESSES[@]}"; do
    if [ -n "${PRIVATE_IP_ADDRESSES[$i]}" ]; then
      params+=("ParameterKey=PrivateIpAddress$((i+1)),ParameterValue=${PRIVATE_IP_ADDRESSES[$i]}")
    fi
  done
fi

# Add key pair name parameter if provided
if [ -n "$KEY_PAIR_NAME" ]; then
  params+=("ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME")
fi

# Add EBS volume IDs parameters if provided
if [ ${#EBS_VOLUME_IDS[@]} -ne 0 ]; then
  for i in "${!EBS_VOLUME_IDS[@]}"; do
    if [ -n "${EBS_VOLUME_IDS[$i]}" ]; then
      params+=("ParameterKey=EbsVolumeId$((i+1)),ParameterValue=${EBS_VOLUME_IDS[$i]}")
    fi
  done
fi

# Add EFS volume IDs parameters if provided
if [ ${#EFS_VOLUME_IDS[@]} -ne 0 ]; then
  for i in "${!EFS_VOLUME_IDS[@]}"; do
    if [ -n "${EFS_VOLUME_IDS[$i]}" ]; then
      params+=("ParameterKey=EfsVolumeId$((i+1)),ParameterValue=${EFS_VOLUME_IDS[$i]}")
    fi
  done
fi

# Add Vault parameters if creating a Vault
if [[ $CREATE_VAULT = true ]]; then
  params+=(
    "ParameterKey=VaultToken,ParameterValue=$(openssl rand -base64 12)"
  )
fi

# Add tags parameters if provided
if [ ${#TAGS[@]} -ne 0 ]; then
  for i in "${!TAGS[@]}"; do
    if [ -n "${TAGS[$i]}" ]; then
      params+=("ParameterKey=TagKey$((i+1)),ParameterValue=$(echo ${TAGS[$i]} | cut -d'=' -f1)")
      params+=("ParameterKey=TagValue$((i+1)),ParameterValue=$(echo ${TAGS[$i]} | cut -d'=' -f2)")
    fi
  done
fi

# Add Kestra image repository user and password parameters if provided
if [ -n "$KESTRA_IMAGE_REPOSITORY_USER" ] && [ -n "$KESTRA_IMAGE_REPOSITORY_PASSWORD" ]; then
  params+=(
    "ParameterKey=KestraImageRepositoryUser,ParameterValue=$KESTRA_IMAGE_REPOSITORY_USER"
    "ParameterKey=KestraImageRepositoryPassword,ParameterValue=$KESTRA_IMAGE_REPOSITORY_PASSWORD"
  )
fi

cp "./$TEMPLATE_FILE" ./._temp_template.yaml

# Add Kestra init script content to the template if provided
if [ -f $KESTRA_INIT_SCRIPT ]; then
    placeholder="KESTRA_INIT_SCRIPT_PLACEHOLDER"
    indent=$(grep -m 1 "$placeholder" "./._temp_template.yaml" | sed -e "s/$placeholder.*//" | wc -c)
    indent=$((indent-1))
    kestra_init_script_content=$(awk -v indent="$indent" 'NR==1{print; next} {printf "%*s%s\n", indent, "", $0}' "$KESTRA_INIT_SCRIPT")
    awk -v r="$kestra_init_script_content" "BEGIN{replacement=0} /$placeholder/ && !replacement {sub(/$placeholder/, r); replacement=1} 1" \
      "./._temp_template.yaml" > ./.__temp_template.yaml && mv ./.__temp_template.yaml ./._temp_template.yaml
fi

# Add Kestra configuration file content to the template if provided
if [ -f $KESTRA_CONFIG_FILE ]; then
    placeholder="KESTRA_CONFIGURATION_PLACEHOLDER"
    indent=$(grep -m 1 "$placeholder" "./._temp_template.yaml" | sed -e "s/$placeholder.*//" | wc -c)
    indent=$((indent-1))
    kestra_config_file_content=$(awk -v indent="$indent" 'NR==1{print; next} {printf "%*s%s\n", indent, "", $0}' "$KESTRA_CONFIG_FILE")
    awk -v r="$kestra_config_file_content" "BEGIN{replacement=0} /$placeholder/ && !replacement {sub(/$placeholder/, r); replacement=1} 1" \
      "./._temp_template.yaml" > ./.__temp_template.yaml && mv ./.__temp_template.yaml ./._temp_template.yaml
fi

# Deploy the stack
aws --region $AWS_REGION cloudformation create-stack --stack-name $NAME --template-body file://./._temp_template.yaml --capabilities CAPABILITY_NAMED_IAM \
  --parameters "${params[@]}"
aws --region $AWS_REGION cloudformation wait stack-create-complete --stack-name $NAME || true
aws --region $AWS_REGION cloudformation describe-stacks --stack-name $NAME --query "Stacks[0].StackStatus"

rm ./._temp_template.yaml
