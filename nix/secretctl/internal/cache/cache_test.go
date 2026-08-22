package cache

import (
	"bytes"
	"testing"
	"time"

	"github.com/isala404/dotfiles/secretctl/internal/securestore"
)

type memoryStore struct {
	values map[string][]byte
}

func newMemoryStore() *memoryStore {
	return &memoryStore{values: make(map[string][]byte)}
}

func (s *memoryStore) Set(account string, value []byte) error {
	s.values[account] = append([]byte(nil), value...)
	return nil
}

func (s *memoryStore) Get(account, _ string) ([]byte, error) {
	value, ok := s.values[account]
	if !ok {
		return nil, securestore.ErrNotFound
	}
	return append([]byte(nil), value...), nil
}

func (s *memoryStore) Exists(account string) (bool, error) {
	_, ok := s.values[account]
	return ok, nil
}

func (s *memoryStore) Delete(account string) error {
	delete(s.values, account)
	return nil
}

func TestRoundTrip(t *testing.T) {
	now := time.Unix(1_000, 0)
	cache := New(newMemoryStore())
	cache.now = func() time.Time { return now }

	if err := cache.Set("secret://bws/agents/id", []byte("value")); err != nil {
		t.Fatal(err)
	}
	value, found, err := cache.Get("secret://bws/agents/id")
	if err != nil {
		t.Fatal(err)
	}
	defer clear(value)
	if !found || !bytes.Equal(value, []byte("value")) {
		t.Fatalf("unexpected cache result: found=%v value=%q", found, value)
	}
}

func TestExpiredEntryIsDeleted(t *testing.T) {
	now := time.Unix(1_000, 0)
	store := newMemoryStore()
	cache := New(store)
	cache.now = func() time.Time { return now }
	if err := cache.Set("secret://bws/agents/id", []byte("value")); err != nil {
		t.Fatal(err)
	}

	now = now.Add(TTL)
	value, found, err := cache.Get("secret://bws/agents/id")
	if err != nil {
		t.Fatal(err)
	}
	if found || value != nil {
		t.Fatalf("expired cache entry was returned: found=%v value=%q", found, value)
	}
	if len(store.values) != 0 {
		t.Fatal("expired cache entry was not deleted")
	}
}

func TestReferencesUseSeparateEntries(t *testing.T) {
	store := newMemoryStore()
	cache := New(store)
	if err := cache.Set("secret://bws/agents/one", []byte("one")); err != nil {
		t.Fatal(err)
	}
	if err := cache.Set("secret://bws/agents/two", []byte("two")); err != nil {
		t.Fatal(err)
	}
	if len(store.values) != 2 {
		t.Fatalf("expected two cache entries, got %d", len(store.values))
	}
}
