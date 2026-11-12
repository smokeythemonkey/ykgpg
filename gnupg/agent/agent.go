package agent

import "context"

type Option func(*Config)

type Config struct {
	GpgConf string
}

func WithGpgConf(path string) Option {
	return func(c *Config) { c.GpgConf = path }
}

type Capabilities struct {
	Version string
}

type Agent struct {
	cfg  Config
	home string
}

func New(opts ...Option) *Agent {
	cfg := Config{GpgConf: "gpgconf"}
	for _, opt := range opts {
		opt(&cfg)
	}
	return &Agent{cfg: cfg}
}

func (a *Agent) Home(dir string) *Agent {
	a.home = dir
	return a
}

func (a *Agent) Connect(ctx context.Context) error {
	return ErrNotImplemented
}

func (a *Agent) Capabilities() Capabilities {
	return Capabilities{}
}

func (a *Agent) Close() error {
	return nil
}

func (a *Agent) UpdateStartupTTY(ctx context.Context, tty string) error {
	return ErrNotImplemented
}
