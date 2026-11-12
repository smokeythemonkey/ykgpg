// Package platform isolates the Linux/macOS differences: removable-drive
// roots, clipboard tools, the temp-dir chain, and file mtimes.
package platform

import "errors"

var ErrNotImplemented = errors.New("platform: not implemented")

type OS string

const (
	Linux  OS = "linux"
	Darwin OS = "darwin"
)

type TmpDir struct {
	Path   string
	OnDisk bool
	Warn   string
}

func Current() OS {
	return Linux
}

func RemovableRoots(os OS, user string) []string {
	return nil
}

func RemovableDirs(os OS, user string) []string {
	return nil
}

func TmpChain(os OS, env map[string]string) TmpDir {
	return TmpDir{}
}

func Clipboard(os OS, env map[string]string, text string) error {
	return ErrNotImplemented
}

func Mtime(path string) (int64, error) {
	return 0, ErrNotImplemented
}
