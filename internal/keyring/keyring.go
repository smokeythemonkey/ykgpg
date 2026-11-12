// Package keyring owns the throwaway GNUPGHOME: creation under the
// platform temp chain, agent/scdaemon configuration, card release, and
// the wipe that runs exactly once on success, error, or signal.
package keyring

import (
	"context"
	"errors"

	"github.com/awol/ykgpg/gnupg"
	"github.com/awol/ykgpg/gnupg/agent"
	"github.com/awol/ykgpg/internal/platform"
)

var ErrNotImplemented = errors.New("keyring: not implemented")

type Keyring struct {
	work string
	home string
	g    *gnupg.Client
}

func New(g *gnupg.Client, os platform.OS, env map[string]string) (*Keyring, error) {
	return nil, ErrNotImplemented
}

func (k *Keyring) Work() string {
	return k.work
}

func (k *Keyring) GNUPGHOME() string {
	return k.home
}

func (k *Keyring) Agent() *agent.Agent {
	return k.g.Agent().Home(k.home)
}

func (k *Keyring) Wipe(ctx context.Context) error {
	return ErrNotImplemented
}

func (k *Keyring) ReleaseCard(ctx context.Context) error {
	return ErrNotImplemented
}
