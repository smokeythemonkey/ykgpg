// Package gnupg is a standalone client library for GnuPG: a typed exec
// wrapper over the gpg CLI for keyring work, and (via the agent
// subpackage) an Assuan client for gpg-agent card and agent operations.
// All types are concrete: the package defines no interfaces. Test seams
// are the fake gpg binary (internal/fakegpg) and the loopback Assuan
// server (agent.TestServer).
package gnupg

import "github.com/awol/ykgpg/gnupg/agent"

type Option func(*Config)

type Config struct {
	Binary string
}

func WithBinary(path string) Option {
	return func(c *Config) { c.Binary = path }
}

type Client struct {
	cfg Config
}

func New(opts ...Option) *Client {
	cfg := Config{Binary: "gpg"}
	for _, opt := range opts {
		opt(&cfg)
	}
	return &Client{cfg: cfg}
}

func (c *Client) Keys() *KeysArea {
	return &KeysArea{base: base{client: c}}
}

func (c *Client) KeyGen() *KeyGenArea {
	return &KeyGenArea{base: base{client: c}}
}

func (c *Client) Card() *CardArea {
	return &CardArea{base: base{client: c}}
}

func (c *Client) Edit() *EditArea {
	return &EditArea{base: base{client: c}}
}

func (c *Client) Symmetric() *SymmetricArea {
	return &SymmetricArea{base: base{client: c}}
}

func (c *Client) Agent() *agent.Agent {
	return agent.New()
}
