package config

import (
	"testing"

	"github.com/isala404/dotfiles/secretctl/internal/backend"
	"github.com/isala404/dotfiles/secretctl/internal/policy"
)

func validConfig() Config {
	return Config{
		Version: Version,
		Backends: map[string]backend.Config{
			"bws": {Type: "bws", OrganizationID: "org"},
		},
		Vaults: map[string]Vault{
			"anything": {Backend: "bws", RemoteID: "project", Allow: []policy.Operation{policy.List, policy.Create}},
		},
	}
}

func TestValidateAllowsDynamicVaults(t *testing.T) {
	if err := validConfig().Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestValidateRejectsUnknownOperation(t *testing.T) {
	cfg := validConfig()
	cfg.Vaults["anything"] = Vault{Backend: "bws", RemoteID: "project", Allow: []policy.Operation{"unknown"}}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected invalid operation error")
	}
}

func TestValidateRejectsDuplicateOperation(t *testing.T) {
	cfg := validConfig()
	cfg.Vaults["anything"] = Vault{Backend: "bws", RemoteID: "project", Allow: []policy.Operation{policy.List, policy.List}}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected duplicate operation error")
	}
}

func TestValidateRejectsEmptyBackendType(t *testing.T) {
	cfg := validConfig()
	cfg.Backends["bws"] = backend.Config{}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected empty backend type error")
	}
}
