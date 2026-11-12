// Package ui is the terminal layer: plain prompts on /dev/tty (parity
// with the fish script's look and semantics), plus the explain toggle.
package ui

import (
	"fmt"
	"io"
	"time"
)

type Clock func() time.Time

type UI struct {
	in        io.Reader
	out       io.Writer
	clock     Clock
	explained bool
}

func New(in io.Reader, out io.Writer) *UI {
	return &UI{in: in, out: out, clock: time.Now}
}

func (u *UI) WithClock(c Clock) *UI {
	u.clock = c
	return u
}

func (u *UI) WithExplain(on bool) *UI {
	u.explained = on
	return u
}

func (u *UI) ExplainEnabled() bool {
	return u.explained
}

func (u *UI) Now() time.Time {
	return u.clock()
}

func (u *UI) Header(title string) {
	fmt.Fprintln(u.out, title)
}

func (u *UI) Say(msg string) {
	fmt.Fprintln(u.out, msg)
}

func (u *UI) Ok(msg string) {
	fmt.Fprintln(u.out, "  ✓ "+msg)
}

func (u *UI) Warn(msg string) {
	fmt.Fprintln(u.out, "  ⚠ "+msg)
}

func (u *UI) Ask(prompt, def string) (string, error) {
	return def, ErrNotImplemented
}

func (u *UI) Confirm(question string, def bool) (bool, error) {
	return def, ErrNotImplemented
}

func (u *UI) Pause() error {
	return ErrNotImplemented
}
