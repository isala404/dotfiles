package generate

import "testing"

func TestValue(t *testing.T) {
	value, err := Value(32)
	if err != nil {
		t.Fatal(err)
	}
	if len(value) != 32 {
		t.Fatalf("got length %d", len(value))
	}
}

func TestValueRejectsShortValues(t *testing.T) {
	if _, err := Value(8); err == nil {
		t.Fatal("expected error")
	}
}
