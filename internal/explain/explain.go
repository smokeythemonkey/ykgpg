// Package explain holds the --explain topic registry (hand-written
// teaching text plus source links) and its renderer. Rendered text is
// purely additive: it never changes prompts, defaults, or side effects.
package explain

import "github.com/awol/ykgpg/internal/ui"

type Topic struct {
	ID      string
	Title   string
	Body    string
	Sources []string
}

func Show(u *ui.UI, id string) error {
	if !u.ExplainEnabled() {
		return nil
	}
	return ErrNotImplemented
}
