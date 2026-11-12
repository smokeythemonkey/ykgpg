// Package state stores the non-secret profile state file: fingerprint,
// uid, expiry, subkey capabilities, and card labels. Footprint and card
// serials are metadata, not secrets, but the file is still written 0600
// with a 0700 directory.
package state

import "errors"

var ErrNotImplemented = errors.New("state: not implemented")

type Store struct {
	path string
}

func Open(path string) (*Store, error) {
	return &Store{path: path}, ErrNotImplemented
}

func (s *Store) Get(key string) (string, bool) {
	return "", false
}

func (s *Store) Set(key, value string) error {
	return ErrNotImplemented
}

func (s *Store) ClearPrefix(prefix string) error {
	return ErrNotImplemented
}

func (s *Store) KeysWithPrefix(prefix string) [][2]string {
	return nil
}
