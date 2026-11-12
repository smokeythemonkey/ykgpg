package gnupg

type base struct {
	client   *Client
	home     string
	tty      string
	pinentry string
}
