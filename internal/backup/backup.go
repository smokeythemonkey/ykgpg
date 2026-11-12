// Package backup writes, restores, verifies, rotates, and distributes
// the encrypted key backup. Verification refuses card stubs and counts
// secret keys against the profile's capability list.
package backup

import (
	"context"
	"errors"

	"github.com/awol/ykgpg/gnupg"
	"github.com/awol/ykgpg/internal/keyring"
	"github.com/awol/ykgpg/internal/profile"
	"github.com/awol/ykgpg/internal/ui"
)

var ErrNotImplemented = errors.New("backup: not implemented")

func Write(ctx context.Context, k *keyring.Keyring, fpr gnupg.Fpr, dest string, u *ui.UI) error {
	return ErrNotImplemented
}

func Restore(ctx context.Context, k *keyring.Keyring, src string, u *ui.UI) (gnupg.Fpr, error) {
	return "", ErrNotImplemented
}

func Verify(ctx context.Context, k *keyring.Keyring, fpr gnupg.Fpr, wantSecrets int, u *ui.UI) error {
	return ErrNotImplemented
}

func Find(env map[string]string, p profile.Profile) (string, bool) {
	return "", false
}

func CopyOffline(ctx context.Context, src string, u *ui.UI) (int, error) {
	return 0, ErrNotImplemented
}
