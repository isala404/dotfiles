package securestore

import "errors"

var ErrNotFound = errors.New("credential not found")

type Store interface {
	Set(account string, value []byte) error
	Get(account, reason string) ([]byte, error)
	Exists(account string) (bool, error)
	Delete(account string) error
}

func Account(backend string) string {
	return backend
}
