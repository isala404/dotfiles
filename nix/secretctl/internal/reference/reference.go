package reference

import (
	"fmt"
	"net/url"
	"strings"

	"github.com/isala404/dotfiles/secretctl/internal/backend"
)

func Parse(value string) (backend.Reference, error) {
	u, err := url.Parse(value)
	if err != nil {
		return backend.Reference{}, err
	}
	parts := strings.Split(strings.TrimPrefix(u.Path, "/"), "/")
	if u.Scheme != "secret" || u.Host == "" || len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return backend.Reference{}, fmt.Errorf("invalid secret reference %q", value)
	}
	return backend.Reference{Backend: u.Host, Vault: parts[0], ID: parts[1]}, nil
}
