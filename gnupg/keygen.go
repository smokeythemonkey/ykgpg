package gnupg

import "context"

type KeyGenArea struct {
	base
}

func (a *KeyGenArea) Home(dir string) *KeyGenArea {
	a.home = dir
	return a
}

func (a *KeyGenArea) TTY(tty string) *KeyGenArea {
	a.tty = tty
	return a
}

func (a *KeyGenArea) Pinentry(path string) *KeyGenArea {
	a.pinentry = path
	return a
}

func (a *KeyGenArea) QuickGenerateKey(ctx context.Context, uid, algo, usage, expire string) (Fpr, error) {
	return "", ErrNotImplemented
}

func (a *KeyGenArea) QuickAddKey(ctx context.Context, fpr Fpr, algo, usage, expire string) error {
	return ErrNotImplemented
}

func (a *KeyGenArea) QuickSetExpire(ctx context.Context, fpr Fpr, expire string, subkeys []Fpr) error {
	return ErrNotImplemented
}

func (a *KeyGenArea) Passwd(ctx context.Context, fpr Fpr) error {
	return ErrNotImplemented
}
