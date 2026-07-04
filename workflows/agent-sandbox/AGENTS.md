# Agent Sandbox

This directory is a scratch workspace for autonomous agents. You have broad latitude here — write scripts, fetch data, transform files, run experiments. The goal is to get the user's work done end-to-end without bouncing every step back for approval.

## Who you're working for

- **Isala Piyarisi** — the user. Use his name where it's natural (commit authorship, generated docs, etc.).

Some machines have extra host-specific context (clusters, infra repos) appended at the bottom of this file. If there's a "Host-specific" section below, it applies to the machine you're on right now; if there isn't, assume none of that infrastructure is reachable from here.

## Start here — orient before you act

Two things to do before you touch the task itself.

**1. Load what you already know about the user.** At `.agents/memory/` (relative to this sandbox root) is a small knowledge base built up across sessions. Read it at the start of every task so the user never has to re-explain himself:

- `profile.md` — who Isala is: role, team, the stack and machines he works on, standing context.
- `preferences.md` — how he likes things done: tools, conventions, formats, defaults he's stated, pet peeves.
- `people.md` — colleagues and collaborators who come up, with enough detail to place each one.
- `good-to-know.md` — everything else worth not rediscovering: infra quirks, gotchas, recurring facts.

If the folder or a file doesn't exist yet, create it the first time you have something worth recording. Keep entries dense and factual — this is reference material, not prose. Update it as you learn: the whole point is that the user shouldn't have to tell you the same thing twice.

**2. Decide if this is a new task or a continuation.** Scan the existing task folders, including those already moved into `completed/`. If the request continues, revisits, or expands work from an earlier one, work *inside that folder* and read its `NOTES.txt` first — it's the record of what was tried, what worked, and what was left open. If the task lives in `completed/`, move it back to the root before resuming. Only create a fresh folder for genuinely new work. If it's ambiguous which existing task a request belongs to, ask rather than guess.

## Per-task workspace

For genuinely new work, create a new folder inside this directory named:

```
YYYY-MM-DD-short-task-name
```

Everything for that task lives inside its folder: scratch files, scripts, downloaded data, build artifacts, and its `NOTES.txt`. Anything temporary — downloads, intermediate files, throwaway scripts — goes in a `tmp/` subfolder of the task folder, never in the sandbox root and never in the system `/tmp`. That keeps cleanup to a single `rm -rf` and keeps the root uncluttered.

When you believe the work is finished — either it's genuinely done or it was a one-off — ask the user whether to move the folder into `completed/`. Don't move it unprompted; the user decides. Moving finished work into `completed/` keeps the sandbox root focused on what's active so it doesn't get overwhelming. Leave `NOTES.txt` intact when you move it — a continuation may still need it.

## NOTES.txt — the task log

Every task folder gets a `NOTES.txt`. It's the running record of the task and the first thing a continuation reads, so keep it current as you work, not as an afterthought at the end. Write it for a future reader: either the user catching up, or an agent picking the task back up cold with none of your context.

What goes in it:

- **What you did** — the steps that mattered, the approach taken, key commands or scripts.
- **What worked and what failed** — dead ends, errors, things that looked right but weren't. A failure documented is a failure nobody repeats.
- **What the user needs to know** — decisions made, tradeoffs, assumptions, anything awaiting his attention or sign-off, and open questions.
- **How the task grew** — if the scope expanded or the task was resumed later, append what changed and why so the history stays readable.

This is the sandbox's version of a progress log: anything you'd otherwise jot into a `PROGRESS.md` goes here instead. Dated entries, newest on top, is a fine default. When something you learn is durable rather than task-specific — a preference, a fact about a person, an infra quirk — lift it up into `.agents/memory/` so it outlives the task folder.

## Lean on skills, don't brute-force

When a task looks like something a skill already does, use the skill. Skills are tested, purpose-built capabilities — picking the right one beats grinding out a worse version by hand. Before you start writing a script from scratch, ask whether a skill covers the shape of the work: research, data viz, web testing, document rendering, whatever it is. Brute-forcing past an available skill wastes effort and usually produces something more fragile. Checking whether a skill fits is cheap; the expensive mistake is reinventing one badly.

## Reach for the right CLI tool

Small, sharp command-line tools usually beat writing a program. Prefer them for one-off transforms and inspection:

- `jq` for JSON, `yq` for YAML/XML.
- `awk`, `sed`, `cut`, `sort`, `uniq`, `grep`/`rg` for text and columns.
- `curl` for HTTP, `ffmpeg` for media, `imagemagick` for images, `pandoc` for document conversion.
- `fd` for finding files, `xsv`/`csvkit` for CSV.

Pipe them together rather than writing a script when a pipeline does the job. Drop into `nix shell` for anything not already present (see Installing tools). Reserve a full Python or Node program for logic a pipeline can't express cleanly.

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

- **Temporary, just for this task:** use `nix shell` or Docker, whichever fits. `nix shell` for CLI tools and one-off binaries — `nix shell nixpkgs#ffmpeg nixpkgs#imagemagick` exits clean and nothing persists. Docker when you need a full isolated environment, a service (database, broker), or a pinned OS image — run it with `--rm` so the container is thrown away after. Reach for Nix by default; use Docker when the task needs more than a binary on PATH.
- **Permanent, you'll want it again:** add it to the dotfiles repo at `../..`. The package lists and module configs live there; rebuild with the project's normal flow (`darwin-rebuild switch` etc.). Mention what you added so the user can review.

Do not `brew install` or otherwise pollute the system imperatively.

## Hygiene

- Don't commit anything from inside this sandbox to the dotfiles repo unless the user asks — it's scratch space, not source.
- Large downloads and build artifacts stay in the task folder's `tmp/` so cleanup is one `rm -rf`.
