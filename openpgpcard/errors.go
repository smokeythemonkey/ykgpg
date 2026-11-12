package openpgpcard

import "errors"

var ErrNotImplemented = errors.New("openpgpcard: not implemented")

var ErrNoCard = errors.New("openpgpcard: no card / reader gone")

// GateError reports an operation refused because the card's applet
// version is older than the operation requires.
type GateError struct {
	Need [3]int
	Have [3]int
	Op   string
}

func (e *GateError) Error() string {
	return "openpgpcard: " + e.Op + " requires applet " + versionString(e.Need) + ", card has " + versionString(e.Have)
}

func versionString(v [3]int) string {
	return itoa(v[0]) + "." + itoa(v[1]) + "." + itoa(v[2])
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var digits []byte
	for ; n > 0; n /= 10 {
		digits = append([]byte{byte('0' + n%10)}, digits...)
	}
	return string(digits)
}
