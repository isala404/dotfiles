# Agent Sandbox

This directory is a scratch workspace for autonomous agents. You have broad latitude here — write scripts, fetch data, transform files, run experiments. The goal is to get the user's work done end-to-end without bouncing every step back for approval.

## Who you're working for

- **Isala Piyarisi** — the user. Use his name where it's natural (commit authorship, generated docs, etc.).
- Main Kubernetes cluster: **polaris-v2**. It runs GitOps from the `infra` repo at `../../..` (relative to this directory). Manifests live in `../../../cumulus-gitops` and IaC in `../../../infrastructure-as-code`. Make changes via PRs to that repo, not by `kubectl apply` against the cluster.

## Per-task workspace

For every task, create a new folder inside this directory named:

```
YYYY-MM-DD-short-task-name
```

Keep all scratch files, scripts, downloaded data, and notes for that task inside its folder. Don't pollute the sandbox root. When a task is done, leave the folder so the user can revisit it; the user prunes old ones.

## Runtimes

Two runtimes are pre-wired at the sandbox root. Pick whichever fits the task — Python for data wrangling, scripting, ML, anything with a strong PyPI story; Node/Bun for web stuff, JSON-heavy work, or anything that needs a TS type-checker.

### Python — always via `uv`

- If `.venv/` exists at the sandbox root, activate it: `source .venv/bin/activate.fish` (or the equivalent for the current shell).
- If it does not exist, create it: `uv venv` — then activate.
- Install packages with `uv pip install <pkg>` or `uv add <pkg>` if a `pyproject.toml` is present. Never call bare `pip` or `python -m pip`.
- Run scripts with `uv run script.py` so the venv is honored even without activation.

### Node — always via `bun`

- A `package.json` lives at the sandbox root. Install with `bun add <pkg>`, run with `bun run <script>` or `bun script.ts`.
- Don't introduce `npm`, `pnpm`, or `yarn` lockfiles.

## Secrets — read `../../BWS.md` first

All credentials (AWS, kubeconfig, SSH, GPG, API tokens) live in Bitwarden Secrets Manager. The full setup is documented in `../../BWS.md` — read it before touching anything secret-related.

**Hard rules:**

- **Never** read a secret's value into your context. Don't `cat`, `echo`, `bws secret get ... | tee`, print to logs, paste into a chat reply, or write to an unencrypted file.
- **Always pipe.** Stream the secret directly from `bws` into the consumer:

  ```bash
  bws secret get <id> -o json | jq -r .value | <tool that needs it>
  ```

  or assign to a shell variable that the next command consumes immediately and let the variable fall out of scope.

- Prefer the existing credential helpers (AWS `credential_process`, kubectl exec plugin) over fetching secrets manually. They cache and gate on Touch ID.
- If a task seems to require a secret in plaintext on disk, stop and ask.

## GitHub (`gh`)

The `gh` CLI is authenticated and available. **Get explicit permission before** any action that's visible to others:

- Commenting on issues or PRs.
- Opening, closing, merging, or editing PRs.
- Creating issues, releases, or discussions.
- Pushing branches to shared remotes.

Read-only `gh` calls (`gh pr view`, `gh issue list`, `gh run watch`, etc.) need no approval. The exception is when the user has explicitly told you to do the write action in this session — then proceed.

## Installing tools

- **Temporary, just for this task:** drop into a `nix shell` with what you need. Example: `nix shell nixpkgs#ffmpeg nixpkgs#imagemagick` — exits clean, nothing persists.
- **Permanent, you'll want it again:** add it to the dotfiles repo at `../..`. The package lists and module configs live there; rebuild with the project's normal flow (`darwin-rebuild switch` etc.). Mention what you added so the user can review.

Do not `brew install` or otherwise pollute the system imperatively.

## Hygiene

- **No absolute paths that leak the user's directory layout.** Use `~`, `$HOME`, or repo-relative paths in anything that might be shared (scripts, READMEs, gists, PR bodies). The sandbox is on a dev machine but artifacts get sent outward.
- Don't commit anything from inside this sandbox to the dotfiles repo unless the user asks — it's scratch space, not source.
- If you generate large downloads or build artifacts, keep them inside the task folder so cleanup is one `rm -rf`.
