# Kestra AWS Lab

Deploys [Kestra](https://kestra.io/) environments to AWS for development and testing purposes.

## Requirements

- An AWS account with the necessary permissions to create and manage the resources defined in the CloudFormation template.
- An AWS credentials file configured on your system.
- Go installed on your system to build the CLI tool.

## Building the CLI

Before using the Kestra AWS Lab, you need to build the CLI from the source. Navigate to the root of this project and execute the following command:

```bash
go build -C cli -o ../kestra-aws-lab
```

This will create the `kestra-aws-lab` binary in the root of the project.

## Usage

### Deployment

Execute the following command to create the environment:

```bash
kestra-aws-lab deploy -r AWS_REGION -n NAME -t TEMPLATE_FILE [-c] [-b SUBNET_ID -v VPC_ID] [-u SSH_TUNNEL_USER -p SSH_TUNNEL_PASSWORD] [-I PRIVATE_IP_ADDRESSES] [-K KEY_PAIR_NAME] [-x EBS_VOLUME_IDS] [-y EFS_VOLUME_IDS] [-V] [-T TAG] [-i KESTRA_IMAGE (default: kestra/kestra:latest-full)] [-e KESTRA_IMAGE_REPOSITORY_USER -f KESTRA_IMAGE_REPOSITORY_PASSWORD] [-k KESTRA_CONFIG_FILE (default: default.yaml)] [-s KESTRA_INIT_SCRIPT (default: default.sh)] [-U DATABASE_USER (default: kestra)] [-P DATABASE_PASSWORD (default: random generated password)] [-a AWS_PROFILE]
```

Parameters:

* `-r`: (Required) AWS region.
* `-n`: (Required) Deployment name.
* `-t`: (Required) CloudFormation template file (from the template directory).
* `-c`: Create a network; requires -u and -p.
* `-b` and `-v`: Subnet ID and VPC ID (required if not creating a network).
* `-u` and `-p`: SSH Tunnel User and Password (required for network creation).
* `-I`: Comma-separated private IP addresses to use for the Kestra and Database services.
* `-K`: Key Pair Name to use for the EC2 instances.
* `-x` and `-y`: Comma-separated EBS and EFS volume IDs to use for the Kestra and Database storage.
* `-V`: Create a Vault service.
* `-T`: Comma-separated tags in the format "Key1=Value1,Key2=Value2" to apply to the resources.
* `-i`: Kestra image (default: kestra/kestra:latest-full).
* `-e` and `-f`: Kestra image repository user and password.
* `-k`: Kestra config file (default: default.yaml).
* `-s`: Kestra init script (default: default.sh).
* `-U`: Database user (default: kestra).
* `-P`: Database password (default: random generated password).
* `-a`: AWS profile.

### Cleanup

To destroy the environment, ensuring the removal of all AWS resources created, use:

```bash
kestra-aws-lab destroy -r AWS_REGION -n NAME [-a AWS_PROFILE]
```

Be cautious as this will permanently delete all associated resources created by the CloudFormation template.

## Configuration

The Cloudformation stack is defined in the template file from the `template` directory. In the `config` directory, you can find the configuration file passed to the Kestra service. In the `init` directory, you can find the init script that will be executed when the Kestra service starts for the first time.