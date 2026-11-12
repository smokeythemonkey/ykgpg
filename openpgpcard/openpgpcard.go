// Package openpgpcard is a pure-Go client for the OpenPGP smart-card
// application over PC/SC. It replaces every ykman use in ykgpg:
// enumeration, card info, PIN changes, touch policy, cardholder name,
// factory reset. There is exactly one production implementation (PC/SC);
// the only seam is the Transport interface, which exists because CI has
// no smart card. PINs are plain parameters; private key material never
// passes through this package (key import stays with gpg-agent's
// KEYTOCARD).
package openpgpcard

import "context"

type Serial string

type Slot int

const (
	SlotSig Slot = 1
	SlotDec Slot = 2
	SlotAut Slot = 3
)

type TouchPolicy string

const (
	TouchOff         TouchPolicy = "off"
	TouchOn          TouchPolicy = "on"
	TouchFixed       TouchPolicy = "fixed"
	TouchCached      TouchPolicy = "cached"
	TouchCachedFixed TouchPolicy = "cached-fixed"
)

type SlotInfo struct {
	Fpr      string
	Algo     string
	Touch    TouchPolicy
	FprEmpty bool
}

type Info struct {
	Version      [3]int
	PINRetries   int
	AdminRetries int
	Slots        map[Slot]SlotInfo
}

type Card struct {
	serial  Serial
	version [3]int
	trans   Transport
}

func List(ctx context.Context) ([]Serial, error) {
	return nil, ErrNotImplemented
}

func Open(ctx context.Context, s Serial) (*Card, error) {
	return nil, ErrNotImplemented
}

func NewWithTransport(ctx context.Context, t Transport) (*Card, error) {
	c := &Card{trans: t}
	if err := c.discoverSerial(ctx); err != nil {
		return nil, err
	}
	return c, nil
}

func (c *Card) Close() error {
	return nil
}

func (c *Card) Serial() Serial {
	return c.serial
}

func (c *Card) Version() [3]int {
	return c.version
}

func (c *Card) Info(ctx context.Context) (Info, error) {
	return Info{}, ErrNotImplemented
}

func (c *Card) VerifyPIN(ctx context.Context, pin string) error {
	return ErrNotImplemented
}

func (c *Card) ChangePIN(ctx context.Context, old, new string) error {
	return ErrNotImplemented
}

func (c *Card) ChangeAdminPIN(ctx context.Context, old, new string) error {
	return ErrNotImplemented
}

func (c *Card) UnblockPIN(ctx context.Context, adminPIN, newPIN string) error {
	return ErrNotImplemented
}

func (c *Card) SetCardholderName(ctx context.Context, adminPIN, surname, given string) error {
	return ErrNotImplemented
}

func (c *Card) SetTouchPolicy(ctx context.Context, adminPIN string, slot Slot, p TouchPolicy) error {
	return ErrNotImplemented
}

func (c *Card) FactoryReset(ctx context.Context) error {
	return ErrNotImplemented
}
