// Package steps holds one file per command, mirroring the fish script's
// step_* functions one-to-one so legacy/ykgpg.fish stays a readable
// parity reference.
package steps

import (
	"errors"

	"github.com/awol/ykgpg/gnupg"
	"github.com/awol/ykgpg/internal/profile"
	"github.com/awol/ykgpg/internal/state"
	"github.com/awol/ykgpg/internal/ui"
)

var ErrNotImplemented = errors.New("steps: not implemented")

// Deps is the dependency set every step receives. All fields are
// concrete types; the client libraries define no interfaces.
type Deps struct {
	UI       *ui.UI
	Profile  profile.Profile
	State    *state.Store
	GnuPG    *gnupg.Client
	Env      map[string]string
	StateDir string
}
