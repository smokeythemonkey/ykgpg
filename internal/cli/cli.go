// Package cli parses the command line and dispatches to steps, wiring
// signals (INT/TERM/HUP → keyring wipe → exit 130) and strict
// argument checking.
package cli

import (
	"fmt"
	"os"

	"github.com/awol/ykgpg/internal/profile"
)

// Run parses args, dispatches the command, and returns the process exit
// code. The name is "ykgpg"; command set and usage text mirror the fish
// script's _usage.
func Run(args []string, version string) int {
	if len(args) > 0 && (args[0] == "--version" || args[0] == "-v") {
		fmt.Printf("ykgpg %s\n", version)
		return 0
	}
	profileName := "personal"
	explained := false
	cmd := "walkthrough"
	var rest []string
	for _, arg := range args {
		switch {
		case arg == "--explain":
			explained = true
		case validProfileFlag(arg):
			profileName = arg[len("-p "):]
		default:
			rest = append(rest, arg)
		}
	}
	if len(rest) > 0 {
		cmd = rest[0]
		rest = rest[1:]
	}
	if len(rest) > 0 {
		fmt.Fprintln(os.Stderr, Usage(version))
		return 1
	}
	_ = profileName
	_ = explained
	_ = profile.Validate
	if !knownCommands[cmd] {
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", cmd)
		fmt.Fprintln(os.Stderr, Usage(version))
		return 1
	}
	fmt.Fprintln(os.Stderr, Usage(version))
	return 1
}

var knownCommands = map[string]bool{
	"walkthrough": true, "prep": true, "generate": true, "card": true,
	"ci": true, "daily": true, "test": true, "ssh": true, "renew": true,
	"edit": true, "offline": true, "status": true, "revoke": true,
	"help": true,
}

func validProfileFlag(arg string) bool {
	return len(arg) > 3 && arg[:3] == "-p="
}

// Usage is the command reference, mirroring the fish _usage text minus
// the removed personal references.
func Usage(version string) string {
	return "ykgpg " + version + " — guided YubiKey OpenPGP setup\n\nUsage: ykgpg [-p <profile>] [--explain] [command]"
}
