package cache

import (
	"encoding/binary"
	"errors"
	"fmt"
	"time"

	"github.com/isala404/dotfiles/secretctl/internal/securestore"
)

const TTL = 5 * time.Minute

type Cache struct {
	store securestore.Store
	now   func() time.Time
}

func New(store securestore.Store) Cache {
	return Cache{store: store, now: time.Now}
}

func (c Cache) Get(reference string) ([]byte, bool, error) {
	payload, err := c.store.Get(account(reference), "Load cached secret")
	if errors.Is(err, securestore.ErrNotFound) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	defer clear(payload)
	if len(payload) < 8 {
		_ = c.Delete(reference)
		return nil, false, fmt.Errorf("cached secret is corrupt")
	}
	if c.now().Unix() >= int64(binary.BigEndian.Uint64(payload[:8])) {
		if err := c.Delete(reference); err != nil {
			return nil, false, err
		}
		return nil, false, nil
	}
	return append([]byte(nil), payload[8:]...), true, nil
}

func (c Cache) Set(reference string, value []byte) error {
	payload := make([]byte, 8+len(value))
	defer clear(payload)
	binary.BigEndian.PutUint64(payload[:8], uint64(c.now().Add(TTL).Unix()))
	copy(payload[8:], value)
	return c.store.Set(account(reference), payload)
}

func (c Cache) Delete(reference string) error {
	return c.store.Delete(account(reference))
}

func account(reference string) string {
	return "cache:" + reference
}
