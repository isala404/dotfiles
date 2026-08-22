package app

import (
	"context"
	"fmt"

	"github.com/isala404/dotfiles/secretctl/internal/backend"
	"github.com/isala404/dotfiles/secretctl/internal/config"
	"github.com/isala404/dotfiles/secretctl/internal/policy"
)

type Request struct {
	Operation policy.Operation `json:"operation"`
	Vault     string           `json:"vault,omitempty"`
	ID        string           `json:"id,omitempty"`
	Key       string           `json:"key,omitempty"`
	Value     string           `json:"value,omitempty"`
	ValueSet  bool             `json:"valueSet,omitempty"`
	Note      string           `json:"note,omitempty"`
}

type Response struct {
	References []backend.Reference `json:"references,omitempty"`
	Reference  *backend.Reference  `json:"reference,omitempty"`
	Value      *string             `json:"value,omitempty"`
	Deleted    bool                `json:"deleted,omitempty"`
	Error      string              `json:"error,omitempty"`
}

type Runner struct {
	Config    config.Config
	Factories map[string]backend.Factory
}

func (r Runner) Execute(ctx context.Context, request Request, token string) Response {
	return r.executeResponse(ctx, request, token, false)
}

func (r Runner) ExecuteFullAccess(ctx context.Context, request Request, token string) Response {
	return r.executeResponse(ctx, request, token, true)
}

func (r Runner) executeResponse(ctx context.Context, request Request, token string, fullAccess bool) Response {
	response, err := r.execute(ctx, request, token, fullAccess)
	if err != nil {
		return Response{Error: err.Error()}
	}
	return response
}

func (r Runner) execute(ctx context.Context, request Request, token string, fullAccess bool) (Response, error) {
	vault, ok := r.Config.Vaults[request.Vault]
	if !ok {
		return Response{}, fmt.Errorf("unknown vault %q", request.Vault)
	}
	if !fullAccess && !vault.Allows(request.Operation) {
		return Response{}, DeniedError(request.Operation, request.Vault)
	}
	backendConfig, ok := r.Config.Backends[vault.Backend]
	if !ok {
		return Response{}, fmt.Errorf("unknown backend %q", vault.Backend)
	}
	factory, ok := r.Factories[backendConfig.Type]
	if !ok {
		return Response{}, fmt.Errorf("backend type %q is not installed", backendConfig.Type)
	}
	provider, err := factory.Open(ctx, backendConfig, token)
	if err != nil {
		return Response{}, err
	}
	defer provider.Close()

	switch request.Operation {
	case policy.List:
		refs, err := provider.List(ctx, backend.ListOptions{ProjectID: vault.RemoteID})
		if err != nil {
			return Response{}, err
		}
		for i := range refs {
			decorate(&refs[i], vault.Backend, request.Vault, vault.RemoteID)
		}
		return Response{References: refs}, nil
	case policy.Create:
		if request.Key == "" {
			return Response{}, fmt.Errorf("secret key is required")
		}
		if !request.ValueSet {
			return Response{}, fmt.Errorf("secret value is required")
		}
		secret, err := provider.Create(ctx, backend.CreateInput{
			Key:       request.Key,
			Value:     request.Value,
			Note:      request.Note,
			ProjectID: vault.RemoteID,
		})
		if err != nil {
			return Response{}, err
		}
		decorate(&secret.Reference, vault.Backend, request.Vault, vault.RemoteID)
		return Response{Reference: &secret.Reference}, nil
	case policy.Update:
		current, err := r.getInVault(ctx, provider, request.ID, vault.RemoteID)
		if err != nil {
			return Response{}, err
		}
		key := current.Key
		if request.Key != "" {
			key = request.Key
		}
		value := current.Value
		if request.ValueSet {
			value = request.Value
		}
		updated, err := provider.Update(ctx, backend.UpdateInput{
			ID:        request.ID,
			Key:       key,
			Value:     value,
			Note:      current.Note,
			ProjectID: vault.RemoteID,
		})
		if err != nil {
			return Response{}, err
		}
		decorate(&updated.Reference, vault.Backend, request.Vault, vault.RemoteID)
		return Response{Reference: &updated.Reference}, nil
	case policy.Delete:
		if _, err := r.getInVault(ctx, provider, request.ID, vault.RemoteID); err != nil {
			return Response{}, err
		}
		if err := provider.Delete(ctx, request.ID); err != nil {
			return Response{}, err
		}
		return Response{Deleted: true}, nil
	case policy.Reveal:
		secret, err := r.getInVault(ctx, provider, request.ID, vault.RemoteID)
		if err != nil {
			return Response{}, err
		}
		value := secret.Value
		return Response{Value: &value}, nil
	default:
		return Response{}, fmt.Errorf("unsupported operation %q", request.Operation)
	}
}

func DeniedError(operation policy.Operation, vault string) error {
	return fmt.Errorf("%s is not allowed for vault %q; an authorized full-access lease is required", operation, vault)
}

func (r Runner) getInVault(ctx context.Context, provider backend.Backend, id, projectID string) (backend.Secret, error) {
	if id == "" {
		return backend.Secret{}, fmt.Errorf("secret ID is required")
	}
	secret, err := provider.Get(ctx, id)
	if err != nil {
		return backend.Secret{}, err
	}
	if secret.ProjectID != projectID {
		return backend.Secret{}, fmt.Errorf("secret %s does not belong to the selected vault", id)
	}
	return secret, nil
}

func decorate(ref *backend.Reference, backendName, vault, projectID string) {
	ref.Backend = backendName
	ref.Vault = vault
	if ref.ProjectID == "" {
		ref.ProjectID = projectID
	}
}
