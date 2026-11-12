package gnupg

import (
	"context"
	"io"
)

type SymmetricArea struct {
	base
}

func (a *SymmetricArea) Home(dir string) *SymmetricArea {
	a.home = dir
	return a
}

func (a *SymmetricArea) Pinentry(path string) *SymmetricArea {
	a.pinentry = path
	return a
}

func (a *SymmetricArea) Encrypt(ctx context.Context, src io.Reader, dst io.Writer) error {
	return ErrNotImplemented
}

func (a *SymmetricArea) Decrypt(ctx context.Context, src io.Reader, dst io.Writer) error {
	return ErrNotImplemented
}
