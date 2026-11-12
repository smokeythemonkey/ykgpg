package agent

import "context"

type KeyInfo struct {
	Grip   string
	Serial string
	ID     string
	Usage  string
}

type EventCounter struct {
	Any  int
	Key  int
	Card int
}

func (a *Agent) KeyToCard(ctx context.Context, grip, serial, keyRef string, force bool) error {
	return ErrNotImplemented
}

func (a *Agent) DeleteKey(ctx context.Context, grip string, force bool) error {
	return ErrNotImplemented
}

func (a *Agent) LearnForce(ctx context.Context) error {
	return ErrNotImplemented
}

func (a *Agent) SetCardAttr(ctx context.Context, name, value string) error {
	return ErrNotImplemented
}

func (a *Agent) ChangeCardPIN(ctx context.Context, chv int, reset bool) error {
	return ErrNotImplemented
}

func (a *Agent) KeyInfo(ctx context.Context, grip string) (KeyInfo, error) {
	return KeyInfo{}, ErrNotImplemented
}

func (a *Agent) HaveKey(ctx context.Context, grips ...string) (bool, error) {
	return false, ErrNotImplemented
}

func (a *Agent) EventCounter(ctx context.Context) (EventCounter, error) {
	return EventCounter{}, ErrNotImplemented
}
