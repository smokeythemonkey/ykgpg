// Package transcript plays recorded APDU exchanges back over the
// openpgpcard.Transport interface, so tests and the CLI's integration
// tests can drive a card without hardware.
package transcript

import "errors"

var ErrNotImplemented = errors.New("transcript: not implemented")
var ErrUnknownAPDU = errors.New("transcript: unknown APDU")

type Player struct {
	path  string
	calls [][]byte
}

func Load(path string) (*Player, error) {
	return &Player{path: path}, ErrNotImplemented
}

func (p *Player) Transmit(apdu []byte) ([]byte, error) {
	p.calls = append(p.calls, apdu)
	return nil, ErrUnknownAPDU
}

func (p *Player) Close() error {
	return nil
}

func (p *Player) Calls() [][]byte {
	return p.calls
}
