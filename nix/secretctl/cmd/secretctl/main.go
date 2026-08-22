package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"sort"
	"strings"
	"syscall"

	"github.com/isala404/dotfiles/secretctl/internal/app"
	"github.com/isala404/dotfiles/secretctl/internal/backend"
	bwsbackend "github.com/isala404/dotfiles/secretctl/internal/backend/bws"
	"github.com/isala404/dotfiles/secretctl/internal/biometric"
	"github.com/isala404/dotfiles/secretctl/internal/cache"
	"github.com/isala404/dotfiles/secretctl/internal/config"
	"github.com/isala404/dotfiles/secretctl/internal/generate"
	"github.com/isala404/dotfiles/secretctl/internal/policy"
	"github.com/isala404/dotfiles/secretctl/internal/reference"
	"github.com/isala404/dotfiles/secretctl/internal/secureinput"
	"github.com/isala404/dotfiles/secretctl/internal/securestore"
	"github.com/isala404/dotfiles/secretctl/internal/unlock"
)

const version = "0.2.0"

type cli struct {
	stdin  io.Reader
	stdout io.Writer
	stderr io.Writer
	store  securestore.Store
}

func main() {
	command := cli{stdin: os.Stdin, stdout: os.Stdout, stderr: os.Stderr, store: securestore.New()}
	if err := command.run(context.Background(), os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "secretctl:", err)
		os.Exit(1)
	}
}

func (c cli) run(ctx context.Context, args []string) error {
	if len(args) == 0 {
		c.usage()
		return flag.ErrHelp
	}
	switch args[0] {
	case "version", "--version", "-v":
		fmt.Fprintln(c.stdout, version)
		return nil
	case "help", "--help", "-h":
		c.usage()
		return nil
	case "config":
		return c.runConfig(args[1:])
	case "auth":
		return c.runAuth(args[1:])
	case "list":
		return c.runList(ctx, args[1:])
	case "create":
		return c.runCreate(ctx, args[1:])
	case "update":
		return c.runUpdate(ctx, args[1:])
	case "delete":
		return c.runDelete(ctx, args[1:])
	case "reveal":
		return c.runReveal(ctx, args[1:])
	case "full-unlock":
		return c.runFullUnlock(ctx, args[1:])
	case "status":
		return c.runStatus()
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func (c cli) runConfig(args []string) error {
	if len(args) != 1 || args[0] != "show" {
		return fmt.Errorf("usage: secretctl config show")
	}
	cfg, err := loadConfig()
	if err != nil {
		return err
	}
	return writeJSON(c.stdout, cfg)
}

func (c cli) runAuth(args []string) error {
	if len(args) != 2 {
		return fmt.Errorf("usage: secretctl auth <set|status|delete> <backend>")
	}
	action, backendName := args[0], args[1]
	cfg, err := loadConfig()
	if err != nil {
		return err
	}
	if _, ok := cfg.Backends[backendName]; !ok {
		return fmt.Errorf("unknown backend %q", backendName)
	}
	account := securestore.Account(backendName)
	switch action {
	case "set":
		value, err := c.readSensitive("Access token: ", 64<<10)
		if err != nil {
			return err
		}
		value = []byte(strings.TrimSpace(string(value)))
		if len(value) == 0 {
			return fmt.Errorf("access token must be provided on stdin")
		}
		defer clear(value)
		if biometric.Available() {
			if err := biometric.Authenticate("Allow secretctl to store the " + backendName + " access token"); err != nil {
				return err
			}
		}
		if err := c.store.Set(account, value); err != nil {
			return err
		}
		return writeJSON(c.stdout, map[string]any{"backend": backendName, "configured": true})
	case "status":
		exists, err := c.store.Exists(account)
		if err != nil {
			return err
		}
		return writeJSON(c.stdout, map[string]any{"backend": backendName, "configured": exists})
	case "delete":
		if biometric.Available() {
			if err := biometric.Authenticate("Allow secretctl to delete the " + backendName + " access token"); err != nil {
				return err
			}
		}
		if err := c.store.Delete(account); err != nil {
			return err
		}
		return writeJSON(c.stdout, map[string]any{"backend": backendName, "configured": false})
	default:
		return fmt.Errorf("unknown auth command %q", action)
	}
}

func (c cli) runList(ctx context.Context, args []string) error {
	flags := flag.NewFlagSet("list", flag.ContinueOnError)
	flags.SetOutput(c.stderr)
	vaultName := flags.String("vault", "", "vault to list")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("usage: secretctl list [--vault NAME]")
	}
	runtime, err := c.loadRuntime()
	if err != nil {
		return err
	}
	if *vaultName != "" {
		if _, ok := runtime.Config.Vaults[*vaultName]; !ok {
			return fmt.Errorf("unknown vault %q", *vaultName)
		}
	}
	var refs []backend.Reference
	for _, name := range selectedVaults(runtime.Config, *vaultName) {
		response, err := c.execute(ctx, runtime, app.Request{Operation: policy.List, Vault: name})
		if err != nil {
			return err
		}
		refs = append(refs, response.References...)
	}
	sort.Slice(refs, func(i, j int) bool {
		left, right := refs[i], refs[j]
		if left.Backend != right.Backend {
			return left.Backend < right.Backend
		}
		if left.Vault != right.Vault {
			return left.Vault < right.Vault
		}
		if left.Key != right.Key {
			return left.Key < right.Key
		}
		return left.ID < right.ID
	})
	return writeReferences(c.stdout, refs)
}

func (c cli) runCreate(ctx context.Context, args []string) error {
	flags := flag.NewFlagSet("create", flag.ContinueOnError)
	flags.SetOutput(c.stderr)
	vaultName := flags.String("vault", "", "target vault")
	key := flags.String("key", "", "secret key")
	generated := flags.Bool("generate", false, "generate a value internally")
	length := flags.Int("length", 32, "generated value length")
	valueStdin := flags.Bool("value-stdin", false, "read the value from stdin")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("usage: secretctl create --vault NAME --key KEY <--generate|--value-stdin>")
	}
	if *vaultName == "" {
		return fmt.Errorf("--vault is required")
	}
	if *key == "" {
		return fmt.Errorf("--key is required")
	}
	runtime, err := c.loadRuntime()
	if err != nil {
		return err
	}
	if err := ensureAvailable(runtime.Config, *vaultName, policy.Create); err != nil {
		return err
	}
	value, err := c.readValue(*generated, *valueStdin, *length)
	if err != nil {
		return err
	}
	defer clear(value)
	response, err := c.execute(ctx, runtime, app.Request{Operation: policy.Create, Vault: *vaultName, Key: *key, Value: string(value), ValueSet: true})
	if err != nil {
		return err
	}
	return writeReference(c.stdout, *response.Reference)
}

func (c cli) runUpdate(ctx context.Context, args []string) error {
	flags := flag.NewFlagSet("update", flag.ContinueOnError)
	flags.SetOutput(c.stderr)
	key := flags.String("key", "", "new secret key")
	generated := flags.Bool("generate", false, "generate a new value internally")
	length := flags.Int("length", 32, "generated value length")
	valueStdin := flags.Bool("value-stdin", false, "read the new value from stdin")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 1 {
		return fmt.Errorf("usage: secretctl update [--key KEY] [--generate|--value-stdin] <reference>")
	}
	ref, err := reference.Parse(flags.Arg(0))
	if err != nil {
		return err
	}
	valueSet := *generated || *valueStdin
	if *key == "" && !valueSet {
		return fmt.Errorf("update requires --key, --generate, or --value-stdin")
	}
	runtime, err := c.loadRuntime()
	if err != nil {
		return err
	}
	if _, err := validateReference(runtime.Config, ref); err != nil {
		return err
	}
	if err := ensureAvailable(runtime.Config, ref.Vault, policy.Update); err != nil {
		return err
	}
	var value []byte
	if valueSet {
		value, err = c.readValue(*generated, *valueStdin, *length)
		if err != nil {
			return err
		}
		defer clear(value)
	}
	response, err := c.execute(ctx, runtime, app.Request{Operation: policy.Update, Vault: ref.Vault, ID: ref.ID, Key: *key, Value: string(value), ValueSet: valueSet})
	if err != nil {
		return err
	}
	c.invalidateCache(ref.URI())
	return writeReference(c.stdout, *response.Reference)
}

func (c cli) runDelete(ctx context.Context, args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: secretctl delete <reference>")
	}
	ref, err := reference.Parse(args[0])
	if err != nil {
		return err
	}
	runtime, err := c.loadRuntime()
	if err != nil {
		return err
	}
	if _, err := validateReference(runtime.Config, ref); err != nil {
		return err
	}
	if err := ensureAvailable(runtime.Config, ref.Vault, policy.Delete); err != nil {
		return err
	}
	response, err := c.execute(ctx, runtime, app.Request{Operation: policy.Delete, Vault: ref.Vault, ID: ref.ID})
	if err != nil {
		return err
	}
	c.invalidateCache(ref.URI())
	return writeJSON(c.stdout, map[string]any{"ref": ref.URI(), "deleted": response.Deleted})
}

func (c cli) runReveal(ctx context.Context, args []string) error {
	flags := flag.NewFlagSet("reveal", flag.ContinueOnError)
	flags.SetOutput(c.stderr)
	noCache := flags.Bool("no-cache", false, "bypass the cached value")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 1 {
		return fmt.Errorf("usage: secretctl reveal [--no-cache] <reference>")
	}
	ref, err := reference.Parse(flags.Arg(0))
	if err != nil {
		return err
	}
	runtime, err := c.loadRuntime()
	if err != nil {
		return err
	}
	if _, err := validateReference(runtime.Config, ref); err != nil {
		return err
	}
	if err := ensureAvailable(runtime.Config, ref.Vault, policy.Reveal); err != nil {
		return err
	}
	secretCache := cache.New(c.store)
	if !*noCache {
		value, found, err := secretCache.Get(ref.URI())
		if err != nil {
			c.cacheWarning("read", err)
		} else if found {
			defer clear(value)
			_, err = c.stdout.Write(value)
			return err
		}
	}
	response, err := c.execute(ctx, runtime, app.Request{Operation: policy.Reveal, Vault: ref.Vault, ID: ref.ID})
	if err != nil {
		return err
	}
	if response.Value == nil {
		return fmt.Errorf("backend returned no value")
	}
	value := []byte(*response.Value)
	defer clear(value)
	if err := secretCache.Set(ref.URI(), value); err != nil {
		c.cacheWarning("store", err)
	}
	_, err = c.stdout.Write(value)
	return err
}

func (c cli) invalidateCache(reference string) {
	if err := cache.New(c.store).Delete(reference); err != nil {
		c.cacheWarning("invalidate", err)
	}
}

func (c cli) cacheWarning(action string, err error) {
	fmt.Fprintf(c.stderr, "secretctl: warning: could not %s encrypted cache: %v\n", action, err)
}

func (c cli) runFullUnlock(parent context.Context, args []string) error {
	if len(args) != 0 {
		return fmt.Errorf("usage: secretctl full-unlock")
	}
	if !biometric.Available() {
		return fmt.Errorf("full-unlock requires user-presence authentication, which is unavailable on this platform")
	}
	if unlock.Available() {
		return fmt.Errorf("full access is already unlocked")
	}
	runtime, err := c.loadRuntime()
	if err != nil {
		return err
	}
	backendNames := configuredBackends(runtime.Config)
	for _, name := range backendNames {
		exists, err := c.store.Exists(securestore.Account(name))
		if err != nil {
			return err
		}
		if !exists {
			return fmt.Errorf("%s credential is not configured; run `secretctl auth set %s`", name, name)
		}
	}
	if err := biometric.Authenticate("Allow full secretctl access to all configured vaults"); err != nil {
		return err
	}
	tokens := make(map[string][]byte, len(backendNames))
	for _, name := range backendNames {
		token, err := c.store.Get(securestore.Account(name), "Load "+name+" access token")
		if err != nil {
			for _, stored := range tokens {
				clear(stored)
			}
			return err
		}
		tokens[name] = token
	}
	defer func() {
		for _, token := range tokens {
			clear(token)
		}
	}()
	ctx, stop := signal.NotifyContext(parent, os.Interrupt, syscall.SIGTERM)
	defer stop()
	fmt.Fprintln(c.stderr, "Full access unlocked. Press Ctrl-C to lock.")
	return unlock.Serve(ctx, func(ctx context.Context, request app.Request) app.Response {
		vault, ok := runtime.Config.Vaults[request.Vault]
		if !ok {
			return app.Response{Error: fmt.Sprintf("unknown vault %q", request.Vault)}
		}
		token, ok := tokens[vault.Backend]
		if !ok {
			return app.Response{Error: fmt.Sprintf("backend %q is not unlocked", vault.Backend)}
		}
		return runtime.ExecuteFullAccess(ctx, request, string(token))
	})
}

func (c cli) runStatus() error {
	return writeJSON(c.stdout, map[string]any{"fullUnlocked": biometric.Available() && unlock.Available()})
}

func (c cli) execute(ctx context.Context, runtime app.Runner, request app.Request) (app.Response, error) {
	vault, ok := runtime.Config.Vaults[request.Vault]
	if !ok {
		return app.Response{}, fmt.Errorf("unknown vault %q", request.Vault)
	}
	if !vault.Allows(request.Operation) {
		if !biometric.Available() {
			return app.Response{}, deniedError(request.Operation, request.Vault)
		}
		if !unlock.Available() {
			return app.Response{}, deniedError(request.Operation, request.Vault)
		}
		response, err := unlock.Send(ctx, request)
		if err != nil {
			return app.Response{}, err
		}
		if response.Error != "" {
			return app.Response{}, errors.New(response.Error)
		}
		return response, nil
	}
	token, err := c.store.Get(securestore.Account(vault.Backend), "Access "+vault.Backend+" secrets")
	if err != nil {
		if errors.Is(err, securestore.ErrNotFound) {
			return app.Response{}, fmt.Errorf("%s credential is not configured; run `secretctl auth set %s`", vault.Backend, vault.Backend)
		}
		return app.Response{}, err
	}
	defer clear(token)
	response := runtime.Execute(ctx, request, string(token))
	if response.Error != "" {
		return app.Response{}, errors.New(response.Error)
	}
	return response, nil
}

func (c cli) loadRuntime() (app.Runner, error) {
	cfg, err := loadConfig()
	if err != nil {
		return app.Runner{}, err
	}
	return app.Runner{
		Config: cfg,
		Factories: map[string]backend.Factory{
			"bws": bwsbackend.Factory{},
		},
	}, nil
}

func loadConfig() (config.Config, error) {
	path := config.DefaultPath()
	cfg, err := config.Load(path)
	if err != nil {
		return config.Config{}, fmt.Errorf("load %s: %w", path, err)
	}
	return cfg, nil
}

func (c cli) readValue(generated, stdin bool, length int) ([]byte, error) {
	if generated == stdin {
		return nil, fmt.Errorf("choose exactly one of --generate or --value-stdin")
	}
	if generated {
		value, err := generate.Value(length)
		return []byte(value), err
	}
	return c.readSensitive("Secret value: ", 1<<20)
}

func (c cli) readSensitive(prompt string, limit int64) ([]byte, error) {
	if input, ok := c.stdin.(*os.File); ok {
		info, err := input.Stat()
		if err != nil {
			return nil, err
		}
		if info.Mode()&os.ModeCharDevice != 0 {
			return secureinput.Read(prompt)
		}
	}
	return io.ReadAll(io.LimitReader(c.stdin, limit))
}

func ensureAvailable(cfg config.Config, vaultName string, operation policy.Operation) error {
	vault, ok := cfg.Vaults[vaultName]
	if !ok {
		return fmt.Errorf("unknown vault %q", vaultName)
	}
	if vault.Allows(operation) || (biometric.Available() && unlock.Available()) {
		return nil
	}
	return deniedError(operation, vaultName)
}

func deniedError(operation policy.Operation, vault string) error {
	if !biometric.Available() {
		return fmt.Errorf("%s is not allowed for vault %q; full-unlock is unavailable on this platform", operation, vault)
	}
	return fmt.Errorf("%s is not allowed for vault %q; run `secretctl full-unlock` in another terminal and authenticate with Touch ID", operation, vault)
}

func validateReference(cfg config.Config, ref backend.Reference) (config.Vault, error) {
	vault, ok := cfg.Vaults[ref.Vault]
	if !ok {
		return config.Vault{}, fmt.Errorf("unknown vault %q", ref.Vault)
	}
	if vault.Backend != ref.Backend {
		return config.Vault{}, fmt.Errorf("reference backend does not match vault configuration")
	}
	return vault, nil
}

func selectedVaults(cfg config.Config, selected string) []string {
	if selected != "" {
		return []string{selected}
	}
	names := make([]string, 0, len(cfg.Vaults))
	for name := range cfg.Vaults {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

func configuredBackends(cfg config.Config) []string {
	used := make(map[string]struct{})
	for _, vault := range cfg.Vaults {
		used[vault.Backend] = struct{}{}
	}
	names := make([]string, 0, len(used))
	for name := range used {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

type referenceOutput struct {
	Ref string `json:"ref"`
	backend.Reference
}

func writeReference(w io.Writer, ref backend.Reference) error {
	return writeJSON(w, referenceOutput{Ref: ref.URI(), Reference: ref})
}

func writeReferences(w io.Writer, refs []backend.Reference) error {
	output := make([]referenceOutput, 0, len(refs))
	for _, ref := range refs {
		output = append(output, referenceOutput{Ref: ref.URI(), Reference: ref})
	}
	return writeJSON(w, output)
}

func writeJSON(w io.Writer, value any) error {
	encoder := json.NewEncoder(w)
	encoder.SetEscapeHTML(false)
	return encoder.Encode(value)
}

func (c cli) usage() {
	fmt.Fprintln(c.stdout, `secretctl enforces root-owned policy for BWS-backed secret vaults.

Usage:
  secretctl config show
  secretctl auth <set|status|delete> <backend>
  secretctl list [--vault NAME]
  secretctl create --vault NAME --key KEY <--generate|--value-stdin>
  secretctl update [--key KEY] [--generate|--value-stdin] <reference>
  secretctl delete <reference>
  secretctl reveal [--no-cache] <reference>
  secretctl full-unlock
  secretctl status

References use secret://<backend>/<vault>/<id>.
List output is metadata only. Reveal writes the exact value to stdout.
Disallowed operations require full-unlock in another terminal.`)
}
