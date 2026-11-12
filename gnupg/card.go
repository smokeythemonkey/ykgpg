package gnupg

import "context"

// Card reports the three OpenPGP card slots in sig/enc/aut order. An
// empty Fpr means the slot is empty.
type Card struct {
	Serial string
	Slots  [3]Fpr
}

type CardArea struct {
	base
}

func (a *CardArea) Home(dir string) *CardArea {
	a.home = dir
	return a
}

func (a *CardArea) TTY(tty string) *CardArea {
	a.tty = tty
	return a
}

func (a *CardArea) Status(ctx context.Context) (Card, error) {
	return Card{}, ErrNotImplemented
}
