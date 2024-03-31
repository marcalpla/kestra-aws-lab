/*
Copyright © 2024 Marçal Pla <marcal@taleia.software>
*/
package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "kestra-aws-lab",
	Short: "Deploys Kestra environments to AWS",
	Long:  `Deploys Kestra environments to AWS for development and testing purposes.`,
}

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
}
