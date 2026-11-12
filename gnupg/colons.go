package gnupg

// Fpr is a 40- (or, for v5 keys, 64-) hex-character OpenPGP fingerprint.
type Fpr string

// SubKey is one subkey line of a --with-colons listing, in edit-key
// order. Stub reports the field-15 card-stub convention: non-empty and
// not "+" means the secret half lives on a smart card.
type SubKey struct {
	Index        int
	Capabilities string
	Fpr          Fpr
	Validity     string
	Expires      int64
	Stub         bool
}

type PublicKey struct {
	Fpr      Fpr
	UID      string
	Validity string
	Expires  int64
	SubKeys  []SubKey
}

type SecretKey struct {
	Fpr     Fpr
	UID     string
	SubKeys []SubKey
}

func ParseColonList(input string) ([]PublicKey, error) {
	return nil, ErrNotImplemented
}

func ParseColonSecretList(input string) ([]SecretKey, error) {
	return nil, ErrNotImplemented
}
