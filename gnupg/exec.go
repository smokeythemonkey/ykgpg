package gnupg

import (
	"bytes"
	"context"
	"errors"
	"os"
	"os/exec"
	"strings"
)

type result struct {
	stdout string
	stderr string
	err    error
}

var ErrNotImplemented = errors.New("gnupg: not implemented")

// run executes the gpg binary with LC_ALL=C plus the given extra
// environment pairs (GNUPGHOME, GPG_TTY, …), which override inherited
// values, capturing stdout and stderr.
func (c *Client) run(ctx context.Context, env []string, args ...string) result {
	name := c.cfg.Binary
	if name == "" {
		name = "gpg"
	}
	merged := map[string]string{}
	for _, kv := range os.Environ() {
		k, v, ok := strings.Cut(kv, "=")
		if ok {
			merged[k] = v
		}
	}
	for _, kv := range env {
		k, v, ok := strings.Cut(kv, "=")
		if ok {
			merged[k] = v
		}
	}
	merged["LC_ALL"] = "C"

	flat := make([]string, 0, len(merged))
	for k, v := range merged {
		flat = append(flat, k+"="+v)
	}

	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = flat
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	return result{stdout: stdout.String(), stderr: stderr.String(), err: err}
}
