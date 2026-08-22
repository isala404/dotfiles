package app

import (
	"context"
	"testing"

	"github.com/isala404/dotfiles/secretctl/internal/backend"
	"github.com/isala404/dotfiles/secretctl/internal/config"
	"github.com/isala404/dotfiles/secretctl/internal/policy"
)

type fakeFactory struct {
	provider *fakeBackend
}

func (f fakeFactory) Open(context.Context, backend.Config, string) (backend.Backend, error) {
	return f.provider, nil
}

type fakeBackend struct {
	secret backend.Secret
}

func (f *fakeBackend) List(context.Context, backend.ListOptions) ([]backend.Reference, error) {
	return []backend.Reference{f.secret.Reference}, nil
}

func (f *fakeBackend) Get(context.Context, string) (backend.Secret, error) {
	return f.secret, nil
}

func (f *fakeBackend) Create(_ context.Context, input backend.CreateInput) (backend.Secret, error) {
	f.secret = backend.Secret{
		Reference: backend.Reference{ID: "created", Key: input.Key, ProjectID: input.ProjectID},
		Value:     input.Value,
	}
	return f.secret, nil
}

func (f *fakeBackend) Update(_ context.Context, input backend.UpdateInput) (backend.Secret, error) {
	f.secret.Key = input.Key
	f.secret.Value = input.Value
	return f.secret, nil
}

func (*fakeBackend) Delete(context.Context, string) error { return nil }
func (*fakeBackend) Close()                               {}

func testRunner(provider *fakeBackend, allowed ...policy.Operation) Runner {
	return Runner{
		Config: config.Config{
			Version: config.Version,
			Backends: map[string]backend.Config{
				"test": {Type: "fake", OrganizationID: "org"},
			},
			Vaults: map[string]config.Vault{
				"agents": {Backend: "test", RemoteID: "agents-project", Allow: allowed},
			},
		},
		Factories: map[string]backend.Factory{
			"fake": fakeFactory{provider: provider},
		},
	}
}

func TestCreateDoesNotReturnValue(t *testing.T) {
	runner := testRunner(&fakeBackend{}, policy.Create)
	response := runner.Execute(context.Background(), Request{
		Operation: policy.Create,
		Vault:     "agents",
		Key:       "API_KEY",
		Value:     "secret-value",
		ValueSet:  true,
	}, "token")
	if response.Error != "" {
		t.Fatal(response.Error)
	}
	if response.Value != nil {
		t.Fatal("create exposed the secret value")
	}
	if response.Reference == nil || response.Reference.URI() != "secret://test/agents/created" {
		t.Fatalf("unexpected response: %#v", response)
	}
}

func TestRevealRejectsSecretFromAnotherProject(t *testing.T) {
	runner := testRunner(&fakeBackend{secret: backend.Secret{
		Reference: backend.Reference{ID: "secret", ProjectID: "personal-project"},
		Value:     "secret-value",
	}}, policy.Reveal)
	response := runner.Execute(context.Background(), Request{
		Operation: policy.Reveal,
		Vault:     "agents",
		ID:        "secret",
	}, "token")
	if response.Error == "" {
		t.Fatal("expected project boundary error")
	}
	if response.Value != nil {
		t.Fatal("reveal exposed the secret value")
	}
}

func TestDefaultPolicyRejectsDisallowedOperation(t *testing.T) {
	runner := testRunner(&fakeBackend{}, policy.List)
	response := runner.Execute(context.Background(), Request{
		Operation: policy.Delete,
		Vault:     "agents",
		ID:        "secret",
	}, "token")
	if response.Error == "" {
		t.Fatal("expected policy error")
	}
}

func TestFullAccessBypassesOperationPolicy(t *testing.T) {
	runner := testRunner(&fakeBackend{secret: backend.Secret{
		Reference: backend.Reference{ID: "secret", ProjectID: "agents-project"},
	}}, policy.List)
	response := runner.ExecuteFullAccess(context.Background(), Request{
		Operation: policy.Delete,
		Vault:     "agents",
		ID:        "secret",
	}, "token")
	if response.Error != "" {
		t.Fatal(response.Error)
	}
	if !response.Deleted {
		t.Fatal("expected delete to succeed under full access")
	}
}
