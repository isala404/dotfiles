---
name: issue-triage
description: Use when explicitly asked to file, open, raise, or create a GitHub issue. Never for a problem the user merely mentioned in passing filing has to be asked for.
---

# Issue triage

File a short, good-looking GitHub issue that someone else can pick up without asking follow-up questions. Four parts, plain prose, no ceremony.

**Needs:** `gh`, authenticated, in a repo with a GitHub remote. If `gh auth status` fails, stop and say to run `gh auth login`.

## Never file an issue you weren't asked to file

Issues are public and hard to undo. Only act on an explicit ask. Before `gh issue create`, show the target repo from `gh repo view --json nameWithOwner,visibility` (say **PUBLIC** plainly if it is) plus the exact title and body, and wait for a yes.

## 1. Gather context with sub-agents

Don't read the codebase yourself, it burns context you need for writing. Spawn one or two `Explore` agents and ask them for a compact answer: which files and functions the problem lives in, what the code currently does, `file:line` for anything worth pointing at. Tell them to return a short summary, not file dumps.

One agent for "where does X live and what does it do" is usually enough. Add a second only when the issue spans two unrelated areas. Skip sub-agents entirely when the user already handed you the file and the error.

If something stays unknown after that, leave it out. Never invent a line number, an error string, or repro steps to sound concrete.

## 2. Write it

**Title** goes in `--title`. Imperative, names the end state, subsystem visible: `Retry transient upload failures in the worker`, not `Bug in upload`.

**Body** is one lead paragraph and up to three short sections:

```md
The upload worker treats every failed upload as permanent. A dropped connection or a 503 from storage gets logged, and the file is thrown away instead of retried, so one network blip loses data that a retry a second later would have saved.

### What should happen

Transient failures retry with a small bounded backoff. Permanent ones (auth failure, 400s) still fail fast.

### What happens now

`handle_upload` catches every exception the same way and drops the payload. There's no retry path at all.

### Where to look

- `worker/upload.py:88`: `handle_upload`, the catch-all
- `worker/tests/test_upload.py`: no coverage for the failure path
```

Drop "Where to look" if you have nothing real for it. Drop "What happens now" for a feature request where nothing exists yet. Never add sections beyond these: no checklists, no scope tables, no verification block, no "Conclusion".

## 3. Make the prose human

Run the body through the `humanize` skill before you show it. The lead paragraph is the part that matters, it should read like someone explaining the problem to a colleague.

No "delve", "leverage", "robust", "seamless", "crucial", "comprehensive". No em-dashes, curly quotes, or bolded pseudo-headings inside bullets. Report severity as it actually is. No AI attribution, ever. Don't hard-wrap; GitHub soft-wraps, so each paragraph is one line.

## 4. Create it

After the user says yes:

```sh
gh issue create --title "Retry transient upload failures in the worker" --body-file <scratch>/issue-body.md
# --repo owner/name only if they targeted a different repo; --label only if they asked
```

Print the URL `gh` returns.

## Several at once

Group first. Items that live in the same function, share a root cause, or would be one edit become one issue. Different subsystems or different causes stay separate. Show the mapping and the issue count before creating anything, then create in a loop and print every URL. If one fails partway, say which ones exist and which don't.
