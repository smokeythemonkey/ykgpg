package main

import (
	"os"

	"github.com/awol/ykgpg/internal/cli"
)

var version = "0.0.0-dev"

func main() {
	os.Exit(cli.Run(os.Args[1:], version))
}
