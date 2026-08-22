package config

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"github.com/isala404/dotfiles/secretctl/internal/backend"
	"github.com/isala404/dotfiles/secretctl/internal/policy"
)

const (
	Version     = 2
	DefaultFile = "/etc/secretctl/config.json"
)

type Vault struct {
	Backend  string             `json:"backend"`
	RemoteID string             `json:"remoteId"`
	Allow    []policy.Operation `json:"allow"`
}

func (v Vault) Allows(operation policy.Operation) bool {
	for _, allowed := range v.Allow {
		if allowed == operation {
			return true
		}
	}
	return false
}

type Config struct {
	Version  int                       `json:"version"`
	Backends map[string]backend.Config `json:"backends"`
	Vaults   map[string]Vault          `json:"vaults"`
}

func DefaultPath() string {
	return DefaultFile
}

func Load(path string) (Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Config{}, err
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return Config{}, fmt.Errorf("decode config: %w", err)
	}
	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) Validate() error {
	if c.Version != Version {
		return fmt.Errorf("unsupported config version %d", c.Version)
	}
	if len(c.Backends) == 0 {
		return errors.New("config has no backends")
	}
	if len(c.Vaults) == 0 {
		return errors.New("config has no vaults")
	}
	for name, backendConfig := range c.Backends {
		if name == "" || backendConfig.Type == "" {
			return fmt.Errorf("backend %q has an empty name or type", name)
		}
	}
	for name, vault := range c.Vaults {
		if name == "" || vault.RemoteID == "" {
			return fmt.Errorf("vault %q has an empty name or remote ID", name)
		}
		if _, ok := c.Backends[vault.Backend]; !ok {
			return fmt.Errorf("vault %q references unknown backend %q", name, vault.Backend)
		}
		seen := make(map[policy.Operation]struct{}, len(vault.Allow))
		for _, operation := range vault.Allow {
			if !policy.Valid(operation) {
				return fmt.Errorf("vault %q allows invalid operation %q", name, operation)
			}
			if _, ok := seen[operation]; ok {
				return fmt.Errorf("vault %q allows operation %q more than once", name, operation)
			}
			seen[operation] = struct{}{}
		}
	}
	return nil
}
