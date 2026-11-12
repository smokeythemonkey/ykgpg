package openpgpcard

import "context"

// Transport exchanges APDUs with a card. The only implementations are
// the PC/SC one (production, build tag "pcsc") and the transcript player
// in openpgpcard/transcript (tests). It is not a strategy interface.
type Transport interface {
	Transmit(apdu []byte) ([]byte, error)
	Close() error
}

// discoverSerial selects the OpenPGP AID on the transport and reads the
// card serial.
func (c *Card) discoverSerial(ctx context.Context) error {
	return ErrNotImplemented
}
