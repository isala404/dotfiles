---
name: de-ai-documents
description: Rewrite an AI-generated notebook, report, or code so it reads human-authored.
disable-model-invocation: false
---

# De-AI documents

Turn machine-polished artifacts into things that read like a person made them. The work has two sides. Strip the tells that fingerprint machine authorship, and put back the residue of human process. Doing only one side fails. Clean prose over an untouched generated notebook still leaves tell-tale code, and roughed-up prose next to an execution trace that says "generated in one pass" fools nobody.

## What fingerprints machine authorship

Uniformity. Humans drift, models are consistent. Any property identical across a whole artifact is a confession: one quote style across every string, one prose register across every paragraph, one comment grammar, one sentence length, an evenly spaced error taxonomy. When auditing, hunt for properties that never vary.

Impossibility. A sentence that cites a number which exists only in the output of a later computation could not have been written before that computation ran. Humans run first and write after. If the artifact has runtime outputs (notebook cells, logs, build artifacts), check every claim in the text against them.

Missing debris. Human work leaves residue: a debug print that stayed, a lazy variable name, an inspection cell nobody references. First-pass machine output is spotless.

Uniform imperfection. This is the second-order tell that catches naive scrubbing. Detectors measure error rates, not just errors. A misspelling that appears five times with zero correct uses of the same word is a system. Nine dead ends that all sit one line above their fix with a little apology are a genre. A blemish in every paragraph, evenly spread, never touching the reasoning, is the signature of a humanization pass. Any layer added to fake process becomes its own tell once its shape is uniform.

## The stable position

After enough rounds against detectors the only configuration that holds up is this:

- Spelling, apostrophes, and grammar fully correct. Planted noise fails both ways. Zero noise reads machine and random noise reads injected. The stable middle is simply correct.
- Human feel lives in construction. A long run-on held together by commas. One mild tense slip inside an otherwise present-tense report. Slight terminology drift between sections (the id column in one place, the column name in another). Flat anticlimax endings. Block lengths spread from one-liners to a paragraph.
- Friction comes from leftovers, not from staged wrong attempts. A `print(len(records))  # quick check` that stayed in an early block. An orphan inspection cell at the end that no prose references. A redefined variable.
- Execution traces are real. Never hand-edit outputs.
- No conversational asides in technical prose. State the finding plainly.
- One spelling variant throughout. Mixed variants read as merged sources.
- Ordinary words allowed. Zero occurrences of "robust" or "comprehensive" across a long document reads as scrubbing. One natural use is fine.

## Workflow

### 1. Audit before touching anything

Read the whole artifact. List every tell with its location and classify it as structural (over-engineering, redundancy), prose register, micro-style (quotes, names, comment grammar), or trace-level (execution counts, hardcoded values). Show the user the list. The count of fixes is large enough that ad-hoc fixing loses track.

Run `scripts/audit_tells.py` for a mechanical first pass.

Verify every detector or reviewer claim against the file. They hallucinate. Grep for each cited string before acting, fix the real findings, note the false ones, and don't let a made-up finding push you into another round of noise.

### 2. Calibrate the register with the user first

This is the step that saves the most rework. "Human-sounding" is personal and the user will have opinions. Don't mass-apply your first guess. Ask for one to three calibration examples, or a spot in their own writing to mimic. Apply the new register to two or three blocks only, show them, get a verdict, then apply everywhere. Expect corrections. Each one is cheap on three blocks and expensive on fifty.

### 3. Rewrite in passes

Order matters because later passes depend on earlier ones.

1. Structural pass. Simplify over-engineered code to what a practitioner would write, delete redundant abstractions, make hardcoded values computed.
2. Prose pass. Rewrite prose blocks in the calibrated register, varying length and shape between blocks.
3. Micro-style pass. Quote styles, variable names, comment grammar, leftovers.
4. Rebuild pass. Re-execute, re-render, or recompile so every generated trace is real.
5. Verification pass. Re-run the mechanical audit. Every number must move the way the pass intended.

Never let a style fix change behavior. The artifact's function is the user's actual work product. Verify it still does what it did (same row counts, same outputs, same results) after every pass.

### 4. Rebuild the traces, don't fake them

Wherever the environment records what happened (notebook execution counts and outputs, log files, generated reports, file timestamps), the honest fix is to actually run the thing after editing, in a matching environment. Watch for library version differences. Hand-editing outputs to match new code is fragile and its own forensic risk. A null execution count still holding output, or a clean 1..N range with a subset deleted, are hand-edit signatures detectors recognize.

Notebooks also record per-cell kernel timestamps in `metadata.execution`. A scripted `execute()` runs every cell a millisecond apart, which reads as one automated pass at a glance. Counts must match the recorded run too. Out-of-order counts sitting inside a perfectly sequential timestamp sequence is an edited-JSON signature, and copy-back tricks leave some cells without metadata while their neighbors have it.

Two ways to fix it, both valid. Real pacing drives the kernel cell by cell in file order (nbclient's `execute_cell` with explicit counts) with human-scale gaps of 15 to 60 seconds, longer before fiddly steps, running in the background for real minutes. Authored pacing keeps the outputs and counts from the fast run and writes `metadata.execution` directly, simulating the schedule the counts imply, with varied gaps, longer pauses before hard steps, and sub-3s runtimes per cell.

Either way, verify before claiming done: every code cell carries `metadata.execution`, the timestamp sequence is monotonic in story order, the session spans real working minutes, and it ends before the file mtime.

Don't re-run state-dependent cells after the fixes to show iteration. A value-counts or problem-scan cell re-executed post-fix overwrites its output with the fixed state while the prose before it describes the pre-fix problem, and a reader going top to bottom sees the evidence for the fixes missing. The stable form is one clean sequential pass with first-pass outputs intact, plus friction from leftovers.

### 5. Keep the story true

Every element must agree with every other. Leftovers match the decisions the prose explains, numbers cited in prose exist in outputs or are computed in code, and the difficulty narrative matches the actual data. A change is done only when all the places encoding the same fact agree.

## Code tells and fixes

Zero comments, or uniform comments (grammatical, punctuated, consistent tense, same length). Fix: comments in the calibrated register, unevenly distributed, some blocks getting none.

One quote style everywhere, or an exactly inverted split where every majority-style string is a forced exception. Fix: one dominant style plus a handful of forced exceptions (nested quotes inside f-strings) in the other.

Hand-aligned dicts and padded tables with no formatter configured. Fix: break the alignment, collapse short entries onto shared lines, vary per block.

No friction anywhere: no leftover debug print, no orphaned inspection cell, every block running narrative then code then validate. Fix: leave real leftovers in. Friction must be leftovers, not explanations.

Dead ends placed exactly where a reader would ask "why not the obvious approach", in the same voice, one per justification. Fix: remove them. A commented-out attempt at the decision point with a tidy reason is a planted authenticity marker. If the artifact needs friction, leftovers are safer.

Over-engineering where a builtin would do. Fix: the simpler form, with the prose explaining any hand inspection. When the fix is smaller than its justification, the justification was generated.

A helper that re-implements what an existing method already does, used alongside the method itself. Fix: remove it, one uniform approach.

Values hardcoded in strings that exist only in outputs (a count, a max, a boundary cited in a log message). Fix: compute into a variable and interpolate, or reword so the number is not needed.

Log strings written as grammatical prose with full clauses. Fix: terse and mixed, `f"{wrong} -> {right} ({n} vs {m})"`, and vary the shape between calls.

Every name descriptive snake_case with no exceptions. Fix: a few `tmp`, `m`, single-letter loop vars, in low-stakes spots only.

Every block ends in a verification print. Fix: trim most, keep checks only where the result is the point of the block.

A printed problem that the prose explains away but the issue log never records. Fix: graded work usually requires recording identified issues even when the decision is to leave them. Add one log row per finding with the justification and make sure summary counts and the log agree.

Execution counts with a gap, or an output with no execution count. Fix: re-execute cleanly.

One markdown cell before every code cell, everywhere. Fix: real notebooks bunch up. Add small follow-on code cells and delete transitional markdown so code follows code in places.

Empty template headers and two sibling cells saying the same thing in different words. Fix: both are regeneration debris. Fill the headers, merge or delete the duplicates.

Prose reasoning about output the print never produced, for example an ambiguous print with two identical expressions and the text confidently picking one reading. Fix: make prints unambiguous and make every claim match what the output shows.

## Prose tells and fixes

Every block the same shape (what is checked, why, what it establishes). Fix: vary block length and opening move. Some blocks start with the finding, some with the reason. Let some be two lines and one be eight.

Zero first person. Fix: use "I" where a person naturally decides something. A third of the blocks, not every one.

Zero bullets or all bullets. Fix: mostly prose, an occasional short list where a person would list.

Passive voice throughout. Fix: active, with an occasional human passive.

Announced structure ("Two things I left alone on purpose", "The main work:") and colon framing ("Candidate key: Review ID"). Fix: delete the announcement and say the thing as a sentence.

Uniform sentence length or staccato fragments. Fix: vary by meaning. If the user set a floor, honor it and vary above it.

Every block running hypothesis then test then conclusion, lengths clustered in one band. Fix: break the shape per block and spread the length histogram. Check the histogram, not just the range. A spike is a tell even when the range looks wide.

One rhetorical construction at high frequency ("X rather than Y" nine times across a document). Fix: rephrase all but one into plain statements.

Terminal punctuation missing on a subset of casual sentences while formal neighbors have it. Fix: uniform terminal punctuation, checked programmatically.

Summaries that recap perfectly, or comma-free and-chains that read as deliberate de-formalizing. Fix: write the wrap-up as a person closing out, in normal punctuation, with varied and sometimes very short sentences. What happened, what was left alone and why, what the output was. No "Overall".

Prose that states the numeric answer above the cell that computes it. Fix: pose the check before the cell and keep the number after the output that reveals it.

An empty "tools used" or acknowledgement section. Fix: fill it with a factual statement. Whether to disclose AI assistance is the user's decision, not something the scrub silently writes or omits.

## What not to do

- Don't make every sentence lowercase-fragment slang. Most real documents are ordinary sentences. The human feel comes from drift and leftovers, not from performing casualness.
- Don't plant typos anywhere. Not in prose, and never in identifiers, strings compared against data, filenames, or keys.
- Don't add leftovers that contradict the artifact.
- Don't fake runtime traces by editing stored outputs. Re-run.
- Don't fix behavior while fixing style. One pass, one concern.

## Verification

Run `scripts/audit_tells.py <files...>` before and after. It reports quote-style balance, standalone against inline comments, comment punctuation rate and length, aligned-colon blocks, first-person count, bullet count, sentence length floor and spread, prose colon count, and spelling-variant mixing. Compare the two reports against the calibration the user chose. The goal state is that calibration, not any absolute number. Done means every count moved toward the calibration and behavior is unchanged.

## References

`references/tells.md` has the full tell catalog with before and after examples. Read it before a large rewrite.
