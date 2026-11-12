package agent

// TB is the subset of testing.TB the test server needs, so this
// production package does not import testing.
type TB interface {
	Helper()
	Fatal(args ...any)
}

// TestServer is a scriptable Assuan server over a Unix socket, used by
// this package's tests and by the CLI's integration tests.
type TestServer struct {
	path string
}

func StartTestServer(tb TB, script map[string]string) *TestServer {
	tb.Helper()
	return &TestServer{}
}

func (s *TestServer) Path() string {
	return s.path
}

func (s *TestServer) Close() {
}
