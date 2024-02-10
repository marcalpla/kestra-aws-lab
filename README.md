# KestraLab

Deploys an ephemeral [Kestra](https://kestra.io/) environment to AWS for development and testing purposes. It allows for on-demand launching and termination of the services to save costs and ensures data persistence on an EFS volume.

## Requirements

- An AWS account with the necessary permissions to create and manage the resources defined in the CloudFormation template.
- AWS CLI installed and configured.

## Usage

### Deployment

Execute the following command to create the environment:

```bash
./deploy.sh -r AWS_REGION -n NAME -u SSH_TUNNEL_USER -p SSH_TUNNEL_PASSWORD [-a AWS_PROFILE]
```

The `SSH_TUNNEL_USER` and `SSH_TUNNEL_PASSWORD` parameters are utilized to establish a user on the bastion host within the environment, facilitating SSH tunneling to the Kestra web interface, which remains unexposed to the public internet.

### Destruction

Execute the following command to destroy the environment:

```bash
./destroy.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]
```

This will delete all the resources created by the CloudFormation template, including the EFS volume. Be careful, as this operation is irreversible.

### Running

Execute the following command to instantiate the services:

```bash
./run.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]
```

The Kestra and Postgres services will mount the EFS volume to ensure data persistence. Access to the Kestra web interface will be provided through an SSH tunnel to the bastion host.

### Stopping

Execute the following command to terminate the services:

```bash
./stop.sh -r AWS_REGION -n NAME [-a AWS_PROFILE]
```

This will stop all services, but the EFS volume with the data will remain intact.

## Configuration

The `template.yaml` file contains the definition of the CloudFormation stack.