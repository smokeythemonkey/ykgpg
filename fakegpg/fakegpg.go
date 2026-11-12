// Package fakegpg writes a shell script that logs gpg/gpgconf
// invocations and replays canned output keyed by argv. It is a test
// harness: it must never be imported by production code.
package fakegpg

type TB interface {
	Helper()
	Fatal(args ...any)
}

type Call struct {
	Env  map[string]string
	Args []string
}

type Server struct {
	path  string
	calls []Call
}

func Start(tb TB, script string) *Server {
	tb.Helper()
	return &Server{}
}

func (s *Server) BinaryPath() string {
	return s.path
}

func (s *Server) Calls() []Call {
	return s.calls
}

func (s *Server) Close() {
}
