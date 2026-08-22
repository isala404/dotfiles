//go:build darwin && cgo && integration

package securestore

import (
	"bytes"
	"testing"
)

func TestKeychainRoundTrip(t *testing.T) {
	store := New()
	account := "integration-test"
	value := []byte("disposable-test-value")
	if err := store.Delete(account); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := store.Delete(account); err != nil {
			t.Errorf("cleanup Keychain item: %v", err)
		}
	})
	if err := store.Set(account, value); err != nil {
		t.Fatal(err)
	}
	stored, err := store.Get(account, "Verify secretctl Keychain integration")
	if err != nil {
		t.Fatal(err)
	}
	defer clear(stored)
	if !bytes.Equal(stored, value) {
		t.Fatal("Keychain returned a different value")
	}
}
