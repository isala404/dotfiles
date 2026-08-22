# Agent sandbox

This directory is a scratch workspace for autonomous agents. You have broad latitude here. Write scripts, fetch data, transform files, and run experiments. The goal is to get the user's work done end-to-end without bouncing every step back for approval.

## Who you're working for

- **Isala Piyarisi**, the user. Use his name where it's natural (commit authorship, generated docs, etc.).

Some machines have extra host-specific context (clusters, infra repos) appended at the bottom of this file. If there's a "Host-specific" section below, it applies to the machine you're on right now; if there isn't, assume none of that infrastructure is reachable from here.

## Start here and orient before you act

Two things to do before you touch the task itself.

**1. Load what you already know about the user.** At `.agents/memory/` (relative to this sandbox root) is a small knowledge base built up across sessions. Read it at the start of every task so the user never has to re-explain himself:

- `profile.md`, who Isala is: role, employer, machines, standing life context.
- `preferences.md`, how he likes things done: durable defaults and pet peeves that apply across tasks.
- `people.md`, recurring people, one entry each: who they are, how to reach them.
- `good-to-know.md`, durable facts about the machines, accounts, and infrastructure: aliases, quirks, gotchas that will bite again.

If the folder or a file doesn't exist yet, create it the first time you have something worth recording.

**What earns a memory entry.** Every agent reads all of memory before every task, so each entry pays rent in every future context window. The admission test: *would this change what an agent does in a completely different, unrelated task?* A machine alias, a standing account quirk, a durable stated preference, or a recurring person belongs in memory. Findings, evidence, version numbers, hashes, dead ends, and chronology from this task do not. That material belongs in the task's `NOTES.txt`.

When you write memory:

- **One entry, one or two lines, present tense.** State the fact as it stands now. No discovery dates, no "fixed on", and no investigation story. The story lives in the task's `NOTES.txt`.
- **Point, don't copy.** If a future task might need the deep detail, write one line naming the durable fact plus the task folder whose `NOTES.txt` holds the rest. An entry that needs a paragraph to be useful is a task note in the wrong file.
- **Prune as you read.** When you load memory and an entry is stale, superseded, or clearly task-scoped, fix or delete it on the spot. First move anything not already recorded elsewhere into the owning task's `NOTES.txt`. A memory file pushing past ~50 lines is overdue for pruning.

**2. Decide if this is a new task or a continuation.** Scan the existing task folders, including those already moved into `completed/`. If the request continues, revisits, or expands work from an earlier one, work *inside that folder* and read its `NOTES.txt` first. It records what was tried, what worked, and what was left open. If the task lives in `completed/`, move it back to the root before resuming. Only create a fresh folder for genuinely new work. If it's ambiguous which existing task a request belongs to, ask rather than guess.

## Per-task workspace

For genuinely new work, create a new folder inside this directory named:

```
YYYY-MM-DD-short-task-name
```

Everything for that task lives inside its folder: scratch files, scripts, downloaded data, build artifacts, and its `NOTES.txt`. Temporary downloads, intermediate files, and throwaway scripts go in a `tmp/` subfolder of the task folder, never in the sandbox root or the system `/tmp`. That keeps cleanup to a single `rm -rf` and keeps the root uncluttered.

When you believe the work is finished, whether it's genuinely done or was a one-off, ask the user whether to move the folder into `completed/`. Don't move it unprompted; the user decides. Moving finished work into `completed/` keeps the sandbox root focused on what's active so it doesn't get overwhelming. Leave `NOTES.txt` intact when you move it because a continuation may still need it.

## The NOTES.txt task log

Every task folder gets a `NOTES.txt`. It's the running record of the task and the first thing a continuation reads, so keep it current as you work, not as an afterthought at the end. Write it for a future reader: either the user catching up, or an agent picking the task back up cold with none of your context.

What goes in it:

- **What you did**, the steps that mattered, the approach taken, key commands or scripts.
- **What worked and what failed**, dead ends, errors, and things that looked right but weren't. A failure documented is a failure nobody repeats.
- **What the user needs to know**, decisions made, tradeoffs, assumptions, anything awaiting his attention or sign-off, and open questions.
- **How the task grew**, if the scope expanded or the task was resumed later, append what changed and why so the history stays readable.

This is the sandbox's version of a progress log: anything you'd otherwise jot into a `PROGRESS.md` goes here instead. Dated entries, newest on top, is a fine default. When something you learn is durable rather than task-specific, such as a preference, a fact about a person, or an infra quirk, lift it up into `.agents/memory/` so it outlives the task folder, but only if it passes the memory admission test above: one or two lines, the fact, not the story.

## Lean on skills, don't brute-force

When a task looks like something a skill already does, use the skill. Skills are tested, purpose-built capabilities. Picking the right one beats grinding out a worse version by hand. Before you start writing a script from scratch, ask whether a skill covers the shape of the work: research, data viz, web testing, document rendering, or whatever it is. Brute-forcing past an available skill wastes effort and usually produces something more fragile. Checking whether a skill fits is cheap; the expensive mistake is reinventing one badly.

## Reach for the right CLI tool

Small, sharp command-line tools usually beat writing a program. Prefer them for one-off transforms and inspection:

- `jq` for JSON, `yq` for YAML/XML.
- `awk`, `sed`, `cut`, `sort`, `uniq`, `grep`/`rg` for text and columns.
- `curl` for HTTP, `ffmpeg` for media, `imagemagick` for images, `pandoc` for document conversion.
- `fd` for finding files, `xsv`/`csvkit` for CSV.

Pipe them together rather than writing a script when a pipeline does the job. Drop into `nix shell` for anything not already present (see Installing tools). Reserve a full Python or Node program for logic a pipeline can't express cleanly.

## Runtimes

Two runtimes are pre-wired at the sandbox root. Pick whichever fits the task. Use Python for data wrangling, scripting, ML, or anything with a strong PyPI story. Use Node/Bun for web work, JSON-heavy work, or anything that needs a TS type-checker.

### Python, always via `uv`

- If `.venv/` exists at the sandbox root, activate it: `source .venv/bin/activate.fish` (or the equivalent for the current shell).
- If it does not exist, create it with `uv venv`, then activate it.
- Install packages with `uv pip install <pkg>` or `uv add <pkg>` if a `pyproject.toml` is present. Never call bare `pip` or `python -m pip`.
- Run scripts with `uv run script.py` so the venv is honored even without activation.

### Node, always via `bun`

- A `package.json` lives at the sandbox root. Install with `bun add <pkg>`, run with `bun run <script>` or `bun script.ts`.
- Don't introduce `npm`, `pnpm`, or `yarn` lockfiles.

## Secrets: use the `bws-secrets` skill first

All credentials (AWS, kubeconfig, SSH, GPG, API tokens) live in Bitwarden Secrets Manager. The full setup is documented in the `bws-secrets` skill. Read it before touching anything secret-related.

**Hard rules:**

- **Never** read a secret's value into your context. Don't `cat`, `echo`, run raw backend retrieval commands, print to logs, paste into a chat reply, or write to an unencrypted file.
- **Always pipe.** Stream an explicitly authorized secret directly from `secretctl` into the consumer:

  ```bash
  secretctl reveal secret://<backend>/<vault>/<id> | <tool that needs it>
  ```

- Never capture a revealed value in a shell variable, file, clipboard, command argument, log, or model-visible tool result.
- Use `secretctl config show` to inspect the dynamic root-owned policy and `secretctl list` for current references and metadata. They do not return secret values. There is no `get` command.
- Operations listed in a vault's `allow` array run automatically. If `secretctl` denies an operation, ask the user to run `secretctl full-unlock` in another terminal, complete Touch ID, and leave it running while you retry. Never bypass policy with raw BWS or legacy helpers.
- Prefer the existing credential helpers (AWS `credential_process`, kubectl exec plugin) over fetching secrets manually. They use `secretctl` and do not cache plaintext credentials.
- If a task seems to require a secret in plaintext on disk, stop and ask.

## GitHub (`gh`)

The `gh` CLI is authenticated and available. **Get explicit permission before** any action that's visible to others:

- Commenting on issues or PRs.
- Opening, closing, merging, or editing PRs.
- Creating issues, releases, or discussions.
- Pushing branches to shared remotes.

Read-only `gh` calls (`gh pr view`, `gh issue list`, `gh run watch`, etc.) need no approval. The exception is when the user has explicitly told you to do the write action in this session. Then proceed. Also make sure to run `gh` outside the network sandbox.

## Installing tools

- **Temporary, just for this task:** use `nix shell` or Docker, whichever fits. Use `nix shell` for CLI tools and one-off binaries. `nix shell nixpkgs#ffmpeg nixpkgs#imagemagick` exits clean and nothing persists. Use Docker when you need a full isolated environment, a service (database, broker), or a pinned OS image. Run it with `--rm` so the container is thrown away after. Reach for Nix by default; use Docker when the task needs more than a binary on PATH.
- **Permanent, you'll want it again:** add it to the dotfiles repo at `../..`. The package lists and module configs live there; rebuild with the project's normal flow (`darwin-rebuild switch` etc.). Mention what you added so the user can review.

Do not `brew install` or otherwise pollute the system imperatively.

## Hygiene

- Don't commit anything from inside this sandbox to the dotfiles repo unless the user asks. It's scratch space, not source.
- Large downloads and build artifacts stay in the task folder's `tmp/` so cleanup is one `rm -rf`.
