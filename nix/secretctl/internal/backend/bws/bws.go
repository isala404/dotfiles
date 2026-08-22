package bws

import (
	"context"
	"fmt"

	sdk "github.com/bitwarden/sdk-go/v2"
	"github.com/isala404/dotfiles/secretctl/internal/backend"
)

type Factory struct{}

func (Factory) Open(ctx context.Context, cfg backend.Config, token string) (backend.Backend, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if cfg.OrganizationID == "" {
		return nil, fmt.Errorf("bws organization ID is required")
	}
	apiURL := optional(cfg.APIURL)
	identityURL := optional(cfg.IdentityURL)
	client, err := sdk.NewBitwardenClient(apiURL, identityURL)
	if err != nil {
		return nil, fmt.Errorf("initialize bws backend: %w", err)
	}
	if err := client.AccessTokenLogin(token, nil); err != nil {
		client.Close()
		return nil, fmt.Errorf("authenticate bws backend: %w", err)
	}
	return &clientBackend{client: client, organizationID: cfg.OrganizationID}, nil
}

func optional(value string) *string {
	if value == "" {
		return nil
	}
	return &value
}

type clientBackend struct {
	client         sdk.BitwardenClientInterface
	organizationID string
}

func (b *clientBackend) List(ctx context.Context, options backend.ListOptions) ([]backend.Reference, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	identifiers, err := b.client.Secrets().List(b.organizationID)
	if err != nil {
		return nil, fmt.Errorf("list bws secret references: %w", err)
	}
	result := make([]backend.Reference, 0, len(identifiers.Data))
	for _, identifier := range identifiers.Data {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		if !contains(identifier.ProjectIDS, options.ProjectID) {
			continue
		}
		result = append(result, backend.Reference{
			ID:        identifier.ID,
			Key:       identifier.Key,
			ProjectID: options.ProjectID,
		})
	}
	return result, nil
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func (b *clientBackend) Get(ctx context.Context, id string) (backend.Secret, error) {
	if err := ctx.Err(); err != nil {
		return backend.Secret{}, err
	}
	secret, err := b.client.Secrets().Get(id)
	if err != nil {
		return backend.Secret{}, fmt.Errorf("get bws secret %s: %w", id, err)
	}
	return value(*secret), nil
}

func (b *clientBackend) Create(ctx context.Context, input backend.CreateInput) (backend.Secret, error) {
	if err := ctx.Err(); err != nil {
		return backend.Secret{}, err
	}
	secret, err := b.client.Secrets().Create(
		input.Key,
		input.Value,
		input.Note,
		b.organizationID,
		[]string{input.ProjectID},
	)
	if err != nil {
		return backend.Secret{}, fmt.Errorf("create bws secret: %w", err)
	}
	return value(*secret), nil
}

func (b *clientBackend) Update(ctx context.Context, input backend.UpdateInput) (backend.Secret, error) {
	if err := ctx.Err(); err != nil {
		return backend.Secret{}, err
	}
	secret, err := b.client.Secrets().Update(
		input.ID,
		input.Key,
		input.Value,
		input.Note,
		b.organizationID,
		[]string{input.ProjectID},
	)
	if err != nil {
		return backend.Secret{}, fmt.Errorf("update bws secret %s: %w", input.ID, err)
	}
	return value(*secret), nil
}

func (b *clientBackend) Delete(ctx context.Context, id string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	result, err := b.client.Secrets().Delete([]string{id})
	if err != nil {
		return fmt.Errorf("delete bws secret %s: %w", id, err)
	}
	for _, deleted := range result.Data {
		if deleted.ID == id && deleted.Error != nil {
			return fmt.Errorf("delete bws secret %s: %s", id, *deleted.Error)
		}
	}
	return nil
}

func (b *clientBackend) Close() {
	b.client.Close()
}

func reference(secret sdk.SecretResponse) backend.Reference {
	projectID := ""
	if secret.ProjectID != nil {
		projectID = *secret.ProjectID
	}
	createdAt := secret.CreationDate
	revisionAt := secret.RevisionDate
	return backend.Reference{
		ID:         secret.ID,
		Key:        secret.Key,
		ProjectID:  projectID,
		CreatedAt:  &createdAt,
		RevisionAt: &revisionAt,
	}
}

func value(secret sdk.SecretResponse) backend.Secret {
	return backend.Secret{
		Reference: reference(secret),
		Value:     secret.Value,
		Note:      secret.Note,
	}
}
