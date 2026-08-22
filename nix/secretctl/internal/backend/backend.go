package backend

import (
	"context"
	"time"
)

type Config struct {
	Type           string `json:"type"`
	OrganizationID string `json:"organizationId"`
	APIURL         string `json:"apiUrl,omitempty"`
	IdentityURL    string `json:"identityUrl,omitempty"`
}

type Reference struct {
	Backend    string     `json:"backend"`
	Vault      string     `json:"vault"`
	ID         string     `json:"id"`
	Key        string     `json:"key"`
	ProjectID  string     `json:"projectId"`
	CreatedAt  *time.Time `json:"createdAt,omitempty"`
	RevisionAt *time.Time `json:"revisionAt,omitempty"`
}

func (r Reference) URI() string {
	return "secret://" + r.Backend + "/" + r.Vault + "/" + r.ID
}

type Secret struct {
	Reference
	Value string
	Note  string
}

type CreateInput struct {
	Key       string
	Value     string
	Note      string
	ProjectID string
}

type UpdateInput struct {
	ID        string
	Key       string
	Value     string
	Note      string
	ProjectID string
}

type ListOptions struct {
	ProjectID string
}

type Backend interface {
	List(context.Context, ListOptions) ([]Reference, error)
	Get(context.Context, string) (Secret, error)
	Create(context.Context, CreateInput) (Secret, error)
	Update(context.Context, UpdateInput) (Secret, error)
	Delete(context.Context, string) error
	Close()
}

type Factory interface {
	Open(context.Context, Config, string) (Backend, error)
}
