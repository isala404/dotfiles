package bws

import "testing"

func TestContainsProject(t *testing.T) {
	if !contains([]string{"one", "two"}, "two") {
		t.Fatal("expected project match")
	}
	if contains([]string{"one", "two"}, "three") {
		t.Fatal("unexpected project match")
	}
}
