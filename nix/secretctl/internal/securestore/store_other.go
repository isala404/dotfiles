//go:build (!darwin && !linux) || (darwin && !cgo)

package securestore

import "fmt"

type unsupportedStore struct{}

func New() Store { return unsupportedStore{} }

func (unsupportedStore) Set(string, []byte) error {
	return fmt.Errorf("secure credential storage is not implemented on this platform")
}

func (unsupportedStore) Get(string, string) ([]byte, error) {
	return nil, fmt.Errorf("secure credential storage is not implemented on this platform")
}

func (unsupportedStore) Exists(string) (bool, error) {
	return false, fmt.Errorf("secure credential storage is not implemented on this platform")
}

func (unsupportedStore) Delete(string) error {
	return fmt.Errorf("secure credential storage is not implemented on this platform")
}
