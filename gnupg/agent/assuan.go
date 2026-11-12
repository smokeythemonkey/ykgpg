// Package agent speaks the Assuan protocol to gpg-agent, providing the
// card and agent operations gpg itself uses: KEYTOCARD, LEARN, SCD
// SETATTR, SCD PASSWD, KEYINFO, HAVEKEY. PINs and passphrases are never
// sent from here; the agent answers INQUIRE NEEDPIN through pinentry.
package agent

import (
	"context"
	"errors"
)

var ErrNotImplemented = errors.New("agent: not implemented")

type StatusLine struct {
	Keyword string
	Args    string
}

type Response struct {
	Lines []string
	Data  []byte
}

type InquireFunc func(keyword string, status []StatusLine) (string, error)

type Conn struct {
	path string
}

func Dial(ctx context.Context, path string) (*Conn, error) {
	_ = ctx
	return &Conn{path: path}, ErrNotImplemented
}

func (c *Conn) Transact(ctx context.Context, cmd string, inquire InquireFunc) (*Response, error) {
	return nil, ErrNotImplemented
}

func (c *Conn) Close() error {
	return nil
}
