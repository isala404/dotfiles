package reference

import "testing"

func TestParse(t *testing.T) {
	ref, err := Parse("secret://bws/agents/1234")
	if err != nil {
		t.Fatal(err)
	}
	if ref.Backend != "bws" || ref.Vault != "agents" || ref.ID != "1234" {
		t.Fatalf("unexpected reference: %#v", ref)
	}
}

func TestParseRejectsIncompleteReference(t *testing.T) {
	for _, value := range []string{"1234", "secret://bws/agents", "secret:///agents/1234"} {
		if _, err := Parse(value); err == nil {
			t.Fatalf("expected %q to fail", value)
		}
	}
}
