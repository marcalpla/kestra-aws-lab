/*
Copyright © 2024 Marçal Pla <marcal@taleia.software>
*/
package cmd

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudformation"
	"github.com/aws/aws-sdk-go-v2/service/cloudformation/types"
	"github.com/spf13/cobra"
)

type destroyFlags struct {
	awsRegion  string
	name       string
	awsProfile string
}

var destroyCmd = &cobra.Command{
	Use:   "destroy",
	Short: "Destroy the stack in AWS",
	Long:  `Destroy the stack in AWS. This command will remove all the resources created in AWS.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		flags := destroyFlags{}

		flags.awsRegion, _ = cmd.Flags().GetString("aws-region")
		flags.name, _ = cmd.Flags().GetString("name")
		flags.awsProfile, _ = cmd.Flags().GetString("aws-profile")

		err := destroy(flags)
		if err != nil {
			return err
		}

		return nil
	},
}

func init() {
	destroyCmd.Flags().StringP("aws-region", "r", "", "(Required) AWS region")
	destroyCmd.Flags().StringP("name", "n", "", "(Required) Stack name")
	destroyCmd.Flags().StringP("aws-profile", "a", "", "AWS profile")

	destroyCmd.MarkFlagRequired("aws-region")
	destroyCmd.MarkFlagRequired("name")

	rootCmd.AddCommand(destroyCmd)
}

func destroy(flags destroyFlags) error {
	configAWS, err := config.LoadDefaultConfig(context.Background(),
		config.WithRegion(flags.awsRegion),
		config.WithSharedConfigProfile(flags.awsProfile),
	)
	if err != nil {
		return err
	}

	client := cloudformation.NewFromConfig(configAWS)

	_, err = client.DeleteStack(context.Background(), &cloudformation.DeleteStackInput{
		StackName: aws.String(flags.name),
	})
	if err != nil {
		return err
	}

	// Wait for the stack to be deleted
	for {
		time.Sleep(3 * time.Second)

		describeStacksOutput, err := client.DescribeStacks(context.Background(), &cloudformation.DescribeStacksInput{
			StackName: aws.String(flags.name),
		})
		if err != nil {
			break
		}

		if len(describeStacksOutput.Stacks) == 0 {
			return fmt.Errorf("stack not found")
		}

		stack := describeStacksOutput.Stacks[0]

		fmt.Printf("Stack status: %s\n", string(stack.StackStatus))

		if stack.StackStatus == types.StackStatusDeleteComplete {
			break
		}

		if stack.StackStatus == types.StackStatusDeleteFailed {
			return fmt.Errorf("stack delete failed")
		}
	}

	return nil
}
