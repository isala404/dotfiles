//go:build linux

package securestore

import (
	"bytes"
	"crypto/sha256"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type systemdStore struct {
	directory string
}

func New() Store {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return errorStore{err: fmt.Errorf("find user config directory: %w", err)}
	}
	return systemdStore{directory: filepath.Join(configDir, "secretctl", "credentials")}
}

func (s systemdStore) Set(account string, value []byte) error {
	if err := s.ensureDirectory(); err != nil {
		return err
	}
	name := credentialName(account)
	command := exec.Command("/usr/bin/systemd-creds", "encrypt", "--user", "--name="+name, "-", "-")
	command.Stdin = bytes.NewReader(value)
	var stderr bytes.Buffer
	command.Stderr = &stderr
	encrypted, err := command.Output()
	if err != nil {
		return commandError("encrypt", stderr.String(), err)
	}

	temporary, err := os.CreateTemp(s.directory, ".credential-*")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return err
	}
	if _, err := temporary.Write(encrypted); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, s.path(account))
}

func (s systemdStore) Get(account, _ string) ([]byte, error) {
	path := s.path(account)
	if err := validateCredentialFile(path); err != nil {
		return nil, err
	}
	command := exec.Command("/usr/bin/systemd-creds", "decrypt", "--user", "--name="+credentialName(account), path, "-")
	var stderr bytes.Buffer
	command.Stderr = &stderr
	value, err := command.Output()
	if err != nil {
		return nil, commandError("decrypt", stderr.String(), err)
	}
	return value, nil
}

func (s systemdStore) Exists(account string) (bool, error) {
	err := validateCredentialFile(s.path(account))
	if errors.Is(err, ErrNotFound) {
		return false, nil
	}
	return err == nil, err
}

func (s systemdStore) Delete(account string) error {
	err := os.Remove(s.path(account))
	if os.IsNotExist(err) {
		return nil
	}
	return err
}

func (s systemdStore) ensureDirectory() error {
	if err := os.MkdirAll(s.directory, 0o700); err != nil {
		return err
	}
	return os.Chmod(s.directory, 0o700)
}

func (s systemdStore) path(account string) string {
	return filepath.Join(s.directory, credentialName(account)+".cred")
}

func credentialName(account string) string {
	digest := sha256.Sum256([]byte(account))
	return fmt.Sprintf("secretctl-%x", digest[:16])
}

func validateCredentialFile(path string) error {
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("credential path is not a regular file: %s", path)
	}
	if info.Mode().Perm()&0o077 != 0 {
		return fmt.Errorf("credential file permissions are too broad: %s", path)
	}
	return nil
}

func commandError(action, stderr string, err error) error {
	message := strings.TrimSpace(stderr)
	if message == "" {
		return fmt.Errorf("systemd-creds %s: %w", action, err)
	}
	return fmt.Errorf("systemd-creds %s: %s", action, message)
}

type errorStore struct {
	err error
}

func (s errorStore) Set(string, []byte) error           { return s.err }
func (s errorStore) Get(string, string) ([]byte, error) { return nil, s.err }
func (s errorStore) Exists(string) (bool, error)        { return false, s.err }
func (s errorStore) Delete(string) error                { return s.err }
