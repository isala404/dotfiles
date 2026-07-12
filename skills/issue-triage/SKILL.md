---
name: issue-triage
description: Draft and open GitHub issues on the current repo, single or bulk, merging overlapping concerns into fewer issues. Use only when explicitly asked to file one; always confirm the target repo and full issue before creating, since the repo may be public.
---

# Issue triage

Turn a problem discovered in conversation or in the code into a clean, self-contained GitHub issue that another engineer (or agent) could pick up without asking follow-up questions. The value is in two things: a rigid, skimmable structure, and prose that reads like a person wrote it rather than a model.

## The one rule that overrides everything: never open an issue you weren't asked to open

Creating a GitHub issue is a public, hard-to-undo action. On a public repo it's visible to the world, it emails every watcher, and deleting it later doesn't unsend any of that. So:

- Only act when the user has **explicitly** asked to open / file / create / raise an issue. "This is a bug" or "that's annoying" is not a request to file anything. If you're inferring the intent rather than reading it, stop and ask first.
- Before you run `gh issue create`, always show the user two things and wait for an explicit yes:
  1. **The exact target**, from `gh repo view --json nameWithOwner,visibility`, printed as e.g. `isala404/dotfiles (PUBLIC)`. Call out `PUBLIC` plainly so a wrong repo is obvious.
  2. **The full rendered issue** — title and body exactly as it will be posted.
- If the user named a different repo than the one you're in, pass `--repo owner/name` and confirm that repo's visibility too. Never guess the repo.

A good confirmation prompt is short: "This will open a **public** issue on `isala404/dotfiles`. Here's the exact title and body [...]. Go ahead?" Then wait.

## Workflow

### 1. Understand the problem well enough to write it down

Read enough to fill the template truthfully. That usually means the code the problem lives in, its callers, and any test that covers it. The issue should stand on its own, so resolve vague references ("the retry thing") into concrete files, symbols, and observed behaviour before you write. If you genuinely can't determine something (repro steps, the right owner area), leave it out or say it's unknown rather than inventing a plausible-sounding detail.

### 2. Fill the template

The exact structure lives in `assets/issue-template.md`. Read it and follow it section for section. Notes on the parts people get wrong:

- **Title** — a short, specific line naming the outcome you want once the issue is resolved, e.g. `Retry transient upload failures in the worker`. Write it in imperative mood, and make it the end state you're after, not a restatement of the bug. If the subsystem isn't obvious from the words, name it in the title so the list is scannable.
- **Problem** — what's wrong and why it matters, at its real severity. State the observed behaviour, not a theory dressed up as fact. If you're not sure a thing is the cause, write "likely" — don't assert it.
- **Expected change** — the outcome you want, not a line-by-line implementation, unless the implementation is genuinely part of the requirement.
- **Scope** — the four bullets (relevant code / in scope / out of scope / preserve) are what stops an implementer from wandering. Fill them from what you actually read. "Out of scope" and "Preserve" are the ones that prevent scope creep and regressions, so don't leave them as boilerplate.
- **Done when** — observable, checkable criteria. Keep the last three standard items (tests cover the change, existing checks pass, no unrelated refactoring) unless they don't apply.
- **Verification** — the real commands an implementer runs to know they're done (the repo's test / lint / typecheck). Check the manifest or `.agents/MEMORIES.md` for the right ones instead of guessing.
- **Evidence** — the actual error, a `file:line` reference, repro steps, or a log. Delete this section if you have nothing real to put in it. An empty "Evidence" heading is worse than none.

### 3. Write it like a person, not a model

A crisp structure filled with model-flavoured prose still reads as machine output, and on a real repo that's the difference between an issue people trust and one they skim past. The rules below are the parts of the humanize guidance that matter for a technical issue. The through-line: **say exactly what's true, at the temperature it's actually true, in plain words.**

- **Drop the AI vocabulary.** No "delve", "leverage", "robust", "seamless", "crucial", "pivotal", "comprehensive", "streamline", "underscore", "foster", "holistic". Say "use", "solid", "important", "reliable", "simplify" — or just describe the thing.
- **Don't inflate.** Report severity as it is. A cosmetic glitch isn't "critical"; a maybe isn't a certainty. Don't editorialize about why quality or correctness matter in grand terms — state the concrete consequence ("expired sessions keep working, so a revoked user stays logged in") and stop.
- **Don't invent specifics.** No made-up line numbers, error strings, repro steps, or frequencies to sound concrete. If a detail is real, use it; if it's vague, keep it vague or leave it out.
- **Plain formatting.** No em-dashes (use a period or comma). Straight quotes, not curly. Sentence-case headings. Don't bold the first few words of every bullet as pseudo-headings. Skip meta-talk like "This issue aims to..." or a "Conclusion" — the template has no room for it anyway.
- **Don't hard-wrap the body.** GitHub renders markdown, so let each paragraph run as one continuous line. Only put a newline in to start a genuinely new paragraph or list item, never to keep lines under some column width. A manually wrapped paragraph renders as one line anyway, but the source is ugly and breaks awkwardly if edited.
- **No filler triads or trailing "-ing" clauses.** "fast, reliable, and efficient" and "..., improving performance" are tells. Two items or four, and end sentences on the point.
- **No AI attribution.** Never add "generated by", "created with Claude", co-author tags, or any footer. The issue reads as the user's own.

Match the repo's own voice where it has one — skim a couple of existing issues if unsure whether the project is terse or detailed, and fit in.

### 4. Add a visual only when it genuinely helps

Most issues are text and should stay text. Add a diagram or annotated screenshot only when it removes real ambiguity a paragraph can't — a data flow the change touches, a confusing UI state, an architecture with several moving parts. When it does help, use the `excalidraw-render` skill for diagrams and save assets to the scratch directory.

Be aware of a hard limitation: `gh` cannot upload images, and issue bodies only render **hosted** URLs, not local file paths. So the flow is: create the issue text-first, then open it in the browser with `gh issue view <number> --web` and tell the user to drag the saved file(s) into the issue, listing the paths. Don't commit assets into the repo to work around this unless the user asks — that pollutes their history for a picture.

### 5. Create it

Once the user has approved the exact title and body:

```sh
# write the body to a scratch file so the exact text is preserved (no shell-quoting surprises)
gh issue create \
  --title "Retry transient upload failures in the worker" \
  --body-file <scratch-dir>/issue-body.md
# add --repo owner/name only if the user targeted a different repo,
# and --label ... only if the user asked for labels
```

Print the issue URL that `gh` returns so the user can jump straight to it. If they wanted visuals, open it with `gh issue view <number> --web` and point them at the files to drag in.

## Filing several issues at once

When the ask is a batch ("open issues for all of these", a list of review findings, a pile of TODOs), the naive move is one issue per item. That floods the tracker with near-duplicates that all point at the same code, and whoever picks them up ends up opening the same file five times. Do the grouping work first, so the backlog reflects units of work rather than raw observations.

The goal is a smaller number of issues covering the exact same work. That last part is the whole point: merging is about issue count, never about dropping scope. Every distinct piece of work from the original list has to survive as its own checklist item under whichever issue absorbs it, so nothing quietly disappears in the merge.

**Merge two items when they're really one unit of work:**

- They touch the same function or file and you'd fix them in the same edit.
- They're several symptoms of one root cause. The merged issue's Problem lists the symptoms, and the fix addresses the cause once.
- Doing one without the other leaves the system half-changed (add a field and migrate its readers, rename a thing and update its callers).
- They're small enough in the same area that a separate issue each is more overhead than the fix.

**Keep them separate when merging would hide work:**

- Different subsystems, or each is shippable on its own and could go to a different person.
- Different root causes, even in the same file.
- One is substantial on its own, and bolting a small unrelated fix onto it buries the small one.

The smell test is the same "one responsibility" rule applied to issues: if describing the merged issue forces an "and" between concerns that aren't actually the same job, split it back apart. Over-merging into a mega-issue is as bad as not merging at all. When two items are distinct but sequential (one blocks the other), keep them as two issues and note the dependency in the body ("blocked by #NN") rather than fusing them.

For a merged issue, the template does the work of showing that scope is preserved: put each merged concern as its own bullet under **In scope** and its own checkbox under **Done when**, and if they were separate symptoms, list them in **Problem**. Reference the original items so the user can see the mapping.

Then confirm the batch as a whole before creating anything. Creating several public issues at once is higher-stakes than one, so show the plan up front: how many items came in, how many issues you'd file, and which items merged into which, with a one-line reason per merge. After the user okays the plan, show each rendered issue (or walk through them), get the go-ahead, then create them in a loop and print every URL. If one `gh issue create` fails partway through, say which ones were created and which weren't rather than silently stopping.

A good plan summary is compact:

```
9 items in, I'd file 5 issues:
  1. Retry transient upload failures        (items 1, 4 — same retry path)
  2. Validate project id on all read routes (items 2, 3, 8 — one missing guard)
  3. Fix flaky clock test                    (item 5)
  4. Document the backup command             (item 6)
  5. Drop the dead migration shim            (items 7, 9 — same removal)
Every original item is a checkbox under one of these. Want to see them?
```

## Example

**User:** "Open an issue on this repo — our upload worker gives up on the first network blip and drops the file, we should retry the transient ones."

**You** confirm the target (`isala404/dotfiles (PUBLIC)`), read the worker code to name the function and the error path, then show the title and body:

**Title:** `Retry transient upload failures in the worker`

```md
## Problem

The upload worker treats every failed upload as permanent. On a transient network error (a dropped connection, a 503 from storage) it logs the error and discards the file instead of retrying. A single blip loses user data that a retry a second later would have saved.

## Expected change

Retry uploads that fail with a transient error, with a small bounded backoff, before giving up. Permanent errors (auth failure, 400s) should still fail fast.

## Scope

* **Relevant code:** `worker/upload.py` — `handle_upload`, `_is_retryable`
* **In scope:** classify transient vs permanent failures; retry transient ones
* **Out of scope:** changing the storage backend or the queue
* **Preserve:** existing behaviour for permanent failures; the current log format

## Done when

* [ ] Transient upload failures retry with bounded backoff
* [ ] Permanent failures still fail immediately, no retry
* [ ] Tests cover both the transient-retry and permanent-fail paths
* [ ] Existing tests and checks pass
* [ ] No unrelated refactoring or behaviour changes

## Verification

​```sh
uv run pytest worker/tests/test_upload.py
​```
```

Then: "This opens a **public** issue on `isala404/dotfiles`. Go ahead?" — and only run `gh issue create` after the user says yes.
