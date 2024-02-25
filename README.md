# Kestra AWS Lab

Deploys [Kestra](https://kestra.io/) environments to AWS for development and testing, and allows high customization with CloudFormation templates, on-demand launch and termination of services to save costs, and ensures data persistence on EBS and EFS volumes.

## Requirements

- An AWS account with the necessary permissions to create and manage the resources defined in the CloudFormation template.
- AWS CLI installed and configured.
- Bash shell.

## Usage

### Deployment

Execute the following command to create the environment:

```bash
./deploy.sh -r AWS_REGION -n NAME -t TEMPLATE_FILE [-c] [-b SUBNET_ID -v VPC_ID] [-u SSH_TUNNEL_USER -p SSH_TUNNEL_PASSWORD] [-x EBS_VOLUME_IDS] [-y EFS_VOLUME_IDS] [-T TAG] [-i KESTRA_IMAGE] [-e KESTRA_IMAGE_REPOSITORY_USER -f KESTRA_IMAGE_REPOSITORY_PASSWORD] [-k KESTRA_CONFIG_FILE] [-s KESTRA_INIT_SCRIPT] [-U POSTGRES_USER] [-P POSTGRES_PASSWORD] [-a AWS_PROFILE]
```

Parameters:

* `-r`: AWS Region.
* `-n`: Deployment name.
* `-t`: CloudFormation template file (from the template directory).
* `-c`: (Optional) Create a network; requires -u and -p.
* `-b` and `-v`: Subnet ID and VPC ID (required if not creating a network).
* `-u` and `-p`: SSH Tunnel User and Password (required for network creation).
* `-x` and `-y`: (Optional) Comma-separated EBS and EFS volume IDs to use for the Kestra and Postgres storage.
* `-T`: (Optional) Tag in Key=Value format.
* `-i`: (Optional) Kestra image (default: kestra/kestra:latest-full).
* `-e` and `-f`: (Optional) Kestra image repository user and password.
* `-k`: (Optional) Kestra config file (default: default.yaml).
* `-s`: (Optional) Kestra init script (default: default.sh).
* `-U`: (Optional) Postgres user (default: kestra).
* `-P`: (Optional) Postgres password (default: random generated password).
* `-a`: (Optional) AWS profile.

### Cleanup

To destroy the environment, ensuring the removal of all AWS resources created, use:

```bash
./destroy.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]
```

Be cautious as this will permanently delete all associated resources created by the CloudFormation template.

### Running

Execute the following command to instantiate the services:

```bash
./run.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]
```

The Kestra and Postgres services will mount the volumes to ensure data persistence.

### Stopping

```bash
./stop.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]
```

Halts all running services but retains the volumes and its data.

## Configuration

The Cloudformation stack is defined in the template file from the `template` directory. In the `config` directory, you can find the configuration file passed to the Kestra container. In the `init` directory, you can find the init script that will be executed when the Kestra container starts for the first time.