// Package profile resolves a key identity's paths and settings, with
// per-profile environment overrides (YKGPG_EXPIRE_<NAME>, …) and the
// legacy-state migration.
package profile

import (
	"errors"
	"regexp"
)

var ErrNotImplemented = errors.New("profile: not implemented")

var ErrInvalidName = errors.New("profile: invalid name (lowercase letters, digits, dashes and underscores only)")

type Profile struct {
	Name            string
	BackupPath      string
	RegistryKeyPath string
	Algo            string
	Expire          string
	StateFile       string
	Personal        bool
}

var validName = regexp.MustCompile(`^[a-z0-9][a-z0-9_-]*$`)

func Validate(name string) error {
	if !validName.MatchString(name) {
		return ErrInvalidName
	}
	return nil
}

func Resolve(name string, env map[string]string, stateDir string) (Profile, error) {
	return Profile{}, ErrNotImplemented
}

func Known(stateDir string) ([]string, error) {
	return nil, ErrNotImplemented
}

func RecordManifest(stateDir, name string) error {
	return ErrNotImplemented
}

func MigrateLegacyState(stateDir string) (bool, error) {
	return false, ErrNotImplemented
}
