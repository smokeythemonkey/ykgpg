package gnupg

import (
	"context"
	"io"
)

type KeysArea struct {
	base
}

func (a *KeysArea) Home(dir string) *KeysArea {
	a.home = dir
	return a
}

func (a *KeysArea) TTY(tty string) *KeysArea {
	a.tty = tty
	return a
}

func (a *KeysArea) Pinentry(path string) *KeysArea {
	a.pinentry = path
	return a
}

func (a *KeysArea) List(ctx context.Context) ([]PublicKey, error) {
	return nil, ErrNotImplemented
}

func (a *KeysArea) ListSecret(ctx context.Context) ([]SecretKey, error) {
	return nil, ErrNotImplemented
}

func (a *KeysArea) Import(ctx context.Context, r io.Reader) error {
	return ErrNotImplemented
}

func (a *KeysArea) ImportOwnertrust(ctx context.Context, r io.Reader) error {
	return ErrNotImplemented
}

func (a *KeysArea) Export(ctx context.Context, fpr Fpr) ([]byte, error) {
	return nil, ErrNotImplemented
}

func (a *KeysArea) ExportSecretSubkey(ctx context.Context, fpr Fpr) ([]byte, error) {
	return nil, ErrNotImplemented
}

func (a *KeysArea) ExportSSHKey(ctx context.Context, fpr Fpr) ([]byte, error) {
	return nil, ErrNotImplemented
}
