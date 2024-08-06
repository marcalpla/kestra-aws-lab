/*
Copyright © 2024 Marçal Pla <marcal@taleia.software>
*/
package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudformation"
	"github.com/aws/aws-sdk-go-v2/service/cloudformation/types"

	"github.com/marcalpla/kestra-aws-lab/cli/internal/utils"
)

type deployFlags struct {
	awsRegion                     string
	name                          string
	templateFile                  string
	createNetwork                 bool
	subnetId                      string
	vpcId                         string
	sshTunnelUser                 string
	sshTunnelPassword             string
	privateIPAddresses            []string
	kestraInstanceType            string
	keyPairName                   string
	ebsVolumeIds                  []string
	efsVolumeIds                  []string
	createVault                   bool
	tags                          []string
	kestraImage                   string
	kestraImageRepositoryUser     string
	kestraImageRepositoryPassword string
	kestraConfigFile              string
	kestraInitScript              string
	javaXmx                       string
	timezone                      string
	databaseUser                  string
	databasePassword              string
	awsProfile                    string
}

var deployCmd = &cobra.Command{
	Use:   "deploy",
	Short: "Deploy the stack to AWS",
	Long:  `Deploy the stack to AWS with specified options.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		flags := deployFlags{}

		flags.awsRegion, _ = cmd.Flags().GetString("aws-region")
		flags.name, _ = cmd.Flags().GetString("name")
		flags.templateFile, _ = cmd.Flags().GetString("template-file")
		flags.createNetwork, _ = cmd.Flags().GetBool("create-network")
		flags.subnetId, _ = cmd.Flags().GetString("subnet-id")
		flags.vpcId, _ = cmd.Flags().GetString("vpc-id")
		flags.sshTunnelUser, _ = cmd.Flags().GetString("ssh-tunnel-user")
		flags.sshTunnelPassword, _ = cmd.Flags().GetString("ssh-tunnel-password")
		flags.privateIPAddresses, _ = cmd.Flags().GetStringSlice("private-ip-addresses")
		flags.kestraInstanceType, _ = cmd.Flags().GetString("kestra-instance-type")
		flags.keyPairName, _ = cmd.Flags().GetString("key-pair-name")
		flags.ebsVolumeIds, _ = cmd.Flags().GetStringSlice("ebs-volume-ids")
		flags.efsVolumeIds, _ = cmd.Flags().GetStringSlice("efs-volume-ids")
		flags.createVault, _ = cmd.Flags().GetBool("create-vault")
		flags.tags, _ = cmd.Flags().GetStringSlice("tags")
		flags.kestraImage, _ = cmd.Flags().GetString("kestra-image")
		flags.kestraImageRepositoryUser, _ = cmd.Flags().GetString("kestra-image-repository-user")
		flags.kestraImageRepositoryPassword, _ = cmd.Flags().GetString("kestra-image-repository-password")
		flags.kestraConfigFile, _ = cmd.Flags().GetString("kestra-config-file")
		flags.kestraInitScript, _ = cmd.Flags().GetString("kestra-init-script")
		flags.javaXmx, _ = cmd.Flags().GetString("java-xmx")
		flags.timezone, _ = cmd.Flags().GetString("timezone")
		flags.databaseUser, _ = cmd.Flags().GetString("database-user")
		flags.databasePassword, _ = cmd.Flags().GetString("database-password")
		flags.awsProfile, _ = cmd.Flags().GetString("aws-profile")

		err := checkCmdFlags(flags)
		if err != nil {
			return err
		}

		template, err := prepareDeployTemplate(flags)
		if err != nil {
			return err
		}

		params, err := prepareDeployParams(flags)
		if err != nil {
			return err
		}

		err = deploy(flags, template, params)
		if err != nil {
			return err
		}

		return nil
	},
}

func init() {
	deployCmd.Flags().StringP("aws-region", "r", "", "(Required) AWS region")
	deployCmd.Flags().StringP("name", "n", "", "(Required) Stack name")
	deployCmd.Flags().StringP("template-file", "t", "", "(Required) CloudFormation name file in template directory")
	deployCmd.Flags().BoolP("create-network", "c", false, "Flag to create a network. If not set, subnet-id and vpc-id parameters are required")
	deployCmd.Flags().StringP("subnet-id", "b", "", "Existing subnet ID")
	deployCmd.Flags().StringP("vpc-id", "v", "", "Existing VPC ID")
	deployCmd.Flags().StringP("ssh-tunnel-user", "u", "", "SSH tunnel user. Required if creating a network")
	deployCmd.Flags().StringP("ssh-tunnel-password", "p", "", "SSH tunnel password. Required if creating a network")
	deployCmd.Flags().StringSliceP("private-ip-addresses", "I", []string{}, "Comma-separated list of private IP addresses")
	deployCmd.Flags().StringP("kestra-instance-type", "m", "t3.large", "Instance type for Kestra EC2 instance")
	deployCmd.Flags().StringP("key-pair-name", "K", "", "The name of the key pair to use for the EC2 instances")
	deployCmd.Flags().StringSliceP("ebs-volume-ids", "x", []string{}, "Comma-separated list of EBS volume IDs")
	deployCmd.Flags().StringSliceP("efs-volume-ids", "y", []string{}, "Comma-separated list of EFS volume IDs")
	deployCmd.Flags().BoolP("create-vault", "V", false, "Flag to create a Vault")
	deployCmd.Flags().StringSliceP("tags", "T", []string{}, "Comma-separated list of tags in the format key=value")
	deployCmd.Flags().StringP("kestra-image", "i", "kestra/kestra:latest-full", "Kestra image")
	deployCmd.Flags().StringP("kestra-image-repository-user", "e", "", "Kestra image repository user")
	deployCmd.Flags().StringP("kestra-image-repository-password", "f", "", "Kestra image repository password")
	deployCmd.Flags().StringP("kestra-config-file", "k", "default.yaml", "Kestra config name file in config directory")
	deployCmd.Flags().StringP("kestra-init-script", "s", "default.sh", "Kestra init name script in init directory")
	deployCmd.Flags().StringP("java-xmx", "j", "512m", "Java Xmx value for the Kestra service")
	deployCmd.Flags().StringP("timezone", "z", "UTC", "Timezone for the Kestra EC2 instance")
	deployCmd.Flags().StringP("database-user", "U", "kestra", "Database user")
	deployCmd.Flags().StringP("database-password", "P", "", "Database password. If not set, a random password is generated")
	deployCmd.Flags().StringP("aws-profile", "a", "", "AWS profile")

	deployCmd.MarkFlagRequired("aws-region")
	deployCmd.MarkFlagRequired("name")
	deployCmd.MarkFlagRequired("template-file")

	rootCmd.AddCommand(deployCmd)
}

func checkCmdFlags(flags deployFlags) error {
	// Check if the create-network flag is set
	if flags.createNetwork {
		if flags.sshTunnelUser == "" || flags.sshTunnelPassword == "" {
			return fmt.Errorf("creating a network requires -u ssh-tunnel-user and -p ssh-tunnel-password")
		}
	} else {
		if flags.subnetId == "" || flags.vpcId == "" {
			return fmt.Errorf("not creating a network requires -b subnet-id and -v vpc-id")
		}
	}

	// Check if the SSH tunnel user and password are set together
	if flags.sshTunnelUser != "" && flags.sshTunnelPassword == "" ||
		flags.sshTunnelUser == "" && flags.sshTunnelPassword != "" {
		return fmt.Errorf("both SSH tunnel user and password are required together")
	}

	// Check if the Kestra image repository user and password are set together
	if flags.kestraImageRepositoryUser != "" && flags.kestraImageRepositoryPassword == "" ||
		flags.kestraImageRepositoryUser == "" && flags.kestraImageRepositoryPassword != "" {
		return fmt.Errorf("both Kestra image repository user and password are required together")
	}

	return nil
}

func prepareDeployTemplate(flags deployFlags) (string, error) {
	exePath, err := os.Executable()
	if err != nil {
		return "", err
	}

	exeDir := filepath.Dir(exePath)

	templateBody, err := os.ReadFile(filepath.Join(exeDir, "template", flags.templateFile))
	if err != nil {
		return "", err
	}

	kestraConfigBody, err := os.ReadFile(filepath.Join(exeDir, "config", flags.kestraConfigFile))
	if err != nil {
		return "", err
	}

	kestraInitScriptBody, err := os.ReadFile(filepath.Join(exeDir, "init", flags.kestraInitScript))
	if err != nil {
		return "", err
	}

	templateBodyString := string(templateBody)

	templateBodyString = utils.ReplacePlaceholder(templateBodyString, "KESTRA_CONFIGURATION_PLACEHOLDER", string(kestraConfigBody))
	templateBodyString = utils.ReplacePlaceholder(templateBodyString, "KESTRA_INIT_SCRIPT_PLACEHOLDER", string(kestraInitScriptBody))

	return templateBodyString, nil
}

func prepareDeployParams(flags deployFlags) ([]types.Parameter, error) {
	// Generate a random database password if not set
	if flags.databasePassword == "" {
		var err error
		flags.databasePassword, err = utils.GenerateRandomBase64String(12)
		if err != nil {
			return nil, err
		}
	}

	// Initialize the parameters array
	params := []types.Parameter{
		{
			ParameterKey:   aws.String("Name"),
			ParameterValue: aws.String(flags.name),
		},
		{
			ParameterKey:   aws.String("CreateNetwork"),
			ParameterValue: aws.String(fmt.Sprintf("%t", flags.createNetwork)),
		},
		{
			ParameterKey:   aws.String("KestraInstanceType"),
			ParameterValue: aws.String(flags.kestraInstanceType),
		},
		{
			ParameterKey:   aws.String("KestraImage"),
			ParameterValue: aws.String(flags.kestraImage),
		},
		{
			ParameterKey:   aws.String("JavaXmx"),
			ParameterValue: aws.String(flags.javaXmx),
		},
		{
			ParameterKey:   aws.String("Timezone"),
			ParameterValue: aws.String(flags.timezone),
		},
		{
			ParameterKey:   aws.String("DatabaseUser"),
			ParameterValue: aws.String(flags.databaseUser),
		},
		{
			ParameterKey:   aws.String("DatabasePassword"),
			ParameterValue: aws.String(flags.databasePassword),
		},
	}

	// Add existing network parameters if not creating a network
	if !flags.createNetwork {
		params = append(params, []types.Parameter{
			{
				ParameterKey:   aws.String("ExistingSubnetId"),
				ParameterValue: aws.String(flags.subnetId),
			},
			{
				ParameterKey:   aws.String("ExistingVpcId"),
				ParameterValue: aws.String(flags.vpcId),
			},
		}...)
	}

	// Add SSH tunnel user and password parameters if provided
	if flags.sshTunnelUser != "" && flags.sshTunnelPassword != "" {
		params = append(params, []types.Parameter{
			{
				ParameterKey:   aws.String("SshTunnelUser"),
				ParameterValue: aws.String(flags.sshTunnelUser),
			},
			{
				ParameterKey:   aws.String("SshTunnelPassword"),
				ParameterValue: aws.String(flags.sshTunnelPassword),
			},
		}...)
	}

	// Add private IP addresses parameters if provided
	if len(flags.privateIPAddresses) > 0 {
		for i, privateIPAddress := range flags.privateIPAddresses {
			params = append(params, types.Parameter{
				ParameterKey:   aws.String(fmt.Sprintf("PrivateIpAddress%d", i+1)),
				ParameterValue: aws.String(privateIPAddress),
			})
		}
	}

	// Add key pair name parameter if provided
	if flags.keyPairName != "" {
		params = append(params, types.Parameter{
			ParameterKey:   aws.String("KeyPairName"),
			ParameterValue: aws.String(flags.keyPairName),
		})
	}

	// Add EBS volume IDs parameters if provided
	if len(flags.ebsVolumeIds) > 0 {
		for i, ebsVolumeId := range flags.ebsVolumeIds {
			params = append(params, types.Parameter{
				ParameterKey:   aws.String(fmt.Sprintf("EbsVolumeId%d", i+1)),
				ParameterValue: aws.String(ebsVolumeId),
			})
		}
	}

	// Add EFS volume IDs parameters if provided
	if len(flags.efsVolumeIds) > 0 {
		for i, efsVolumeId := range flags.efsVolumeIds {
			params = append(params, types.Parameter{
				ParameterKey:   aws.String(fmt.Sprintf("EfsVolumeId%d", i+1)),
				ParameterValue: aws.String(efsVolumeId),
			})
		}
	}

	// Add Vault token parameter if creating a Vault
	if flags.createVault {
		vaultToken, err := utils.GenerateRandomBase64String(12)
		if err != nil {
			return nil, err
		}
		params = append(params, types.Parameter{
			ParameterKey:   aws.String("VaultToken"),
			ParameterValue: aws.String(vaultToken),
		})
	}

	// Add tags parameters if provided
	if len(flags.tags) > 0 {
		for i, tag := range flags.tags {
			params = append(params, []types.Parameter{
				{
					ParameterKey:   aws.String(fmt.Sprintf("TagKey%d", i+1)),
					ParameterValue: aws.String(strings.Split(tag, "=")[0]),
				},
				{
					ParameterKey:   aws.String(fmt.Sprintf("TagValue%d", i+1)),
					ParameterValue: aws.String(strings.Split(tag, "=")[1]),
				},
			}...)
		}
	}

	// Add Kestra image repository user and password parameters if provided
	if flags.kestraImageRepositoryUser != "" && flags.kestraImageRepositoryPassword != "" {
		params = append(params, []types.Parameter{
			{
				ParameterKey:   aws.String("KestraImageRepositoryUser"),
				ParameterValue: aws.String(flags.kestraImageRepositoryUser),
			},
			{
				ParameterKey:   aws.String("KestraImageRepositoryPassword"),
				ParameterValue: aws.String(flags.kestraImageRepositoryPassword),
			},
		}...)
	}

	return params, nil
}

func deploy(flags deployFlags, template string, params []types.Parameter) error {
	configAWS, err := config.LoadDefaultConfig(context.Background(),
		config.WithRegion(flags.awsRegion),
		config.WithSharedConfigProfile(flags.awsProfile),
	)
	if err != nil {
		return err
	}

	client := cloudformation.NewFromConfig(configAWS)

	_, err = client.CreateStack(context.Background(), &cloudformation.CreateStackInput{
		StackName:    aws.String(flags.name),
		TemplateBody: aws.String(template),
		Capabilities: []types.Capability{
			types.CapabilityCapabilityNamedIam,
		},
		Parameters: params,
	})
	if err != nil {
		return err
	}

	// Wait for the stack to be created
	for {
		time.Sleep(3 * time.Second)

		describeStacksOutput, err := client.DescribeStacks(context.Background(), &cloudformation.DescribeStacksInput{
			StackName: aws.String(flags.name),
		})
		if err != nil {
			return err
		}

		if len(describeStacksOutput.Stacks) == 0 {
			return fmt.Errorf("stack not found")
		}

		stack := describeStacksOutput.Stacks[0]

		fmt.Printf("Stack status: %s\n", string(stack.StackStatus))

		if stack.StackStatus == types.StackStatusCreateComplete {
			break
		}

		if stack.StackStatus == types.StackStatusCreateFailed ||
			stack.StackStatus == types.StackStatusRollbackComplete {
			return fmt.Errorf("stack creation failed")
		}
	}

	return nil
}
