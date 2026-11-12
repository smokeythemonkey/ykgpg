package explain

// Topics is the --explain registry, keyed by stable ID. Content arrives
// with the CLI plan's explanation task; steps reference IDs, not prose.
var Topics = map[string]Topic{
	"primary-vs-subkeys":   {},
	"certify-only-offline": {},
	"card-slots":           {},
	"keytocard-stubs":      {},
	"throwaway-keyring":    {},
	"pins-and-retry":       {},
	"touch-policies":       {},
	"agent-and-scdaemon":   {},
	"backup-design":        {},
	"renewal":              {},
	"ci-subkey":            {},
	"ssh-auth":             {},
	"revocation":           {},
	"ownertrust":           {},
}
