package gnupg

import (
	"context"
	"regexp"
	"strconv"
)

type Version struct {
	Major int
	Minor int
	Patch int
	Raw   string
}

func (v Version) AtLeast(major, minor int) bool {
	if v.Major != major {
		return v.Major > major
	}
	return v.Minor >= minor
}

var versionLine = regexp.MustCompile(`^gpg \(GnuPG\) (\S+)`)

var versionParts = regexp.MustCompile(`^(\d+)\.(\d+)(?:\.(\d+))?`)

func ParseVersion(line string) (Version, error) {
	m := versionLine.FindStringSubmatch(line)
	if m == nil {
		return Version{}, ErrNotImplemented
	}
	raw := m[1]
	p := versionParts.FindStringSubmatch(raw)
	if p == nil {
		return Version{}, ErrNotImplemented
	}
	v := Version{Raw: raw}
	v.Major, _ = strconv.Atoi(p[1])
	v.Minor, _ = strconv.Atoi(p[2])
	if p[3] != "" {
		v.Patch, _ = strconv.Atoi(p[3])
	}
	return v, nil
}

func (c *Client) Version(ctx context.Context) (Version, error) {
	res := c.run(ctx, nil, "--version")
	if res.err != nil {
		return Version{}, res.err
	}
	return ParseVersion(res.stdout)
}
