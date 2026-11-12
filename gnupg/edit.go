package gnupg

import "context"

type EditArea struct {
	base
}

func (a *EditArea) Home(dir string) *EditArea {
	a.home = dir
	return a
}

func (a *EditArea) TTY(tty string) *EditArea {
	a.tty = tty
	return a
}

func (a *EditArea) Pinentry(path string) *EditArea {
	a.pinentry = path
	return a
}

func (a *EditArea) Interactive(ctx context.Context, fpr Fpr) error {
	return ErrNotImplemented
}

func (a *EditArea) Script(ctx context.Context, fpr Fpr, cmds []string) error {
	return ErrNotImplemented
}
