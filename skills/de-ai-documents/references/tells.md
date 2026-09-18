# Tell catalog

Concrete before and after patterns for each tell. Numbers are magnitudes, not targets. The goal state is the register the user calibrated.

## Code

### Uniform comments

Before: hundreds of lines with zero comments. A first fix that adds long grammatical comments with perfect punctuation is still wrong:

```python
# median per band, outliers excluded so they don't drag it
```

A typical calibrated register is short inline lowercase comments without punctuation, spread unevenly:

```python
band_median = df.assign(a=valid_age).groupby("age_group")["a"].median()  # median per band
warnings.filterwarnings("ignore")  # hide warnings
```

Mixed tense is fine and human: "infer unit from range", "kept until the age fixes were done", "decided by hand".

### Lopsided quote style

Before: hundreds of strings in one style, a handful in the other, and every one of the handful a forced exception. That is a giveaway in either direction. After: a large majority in the dominant style plus a few organic exceptions, nested quoted keys inside f-strings for example:

```python
f"{row['flag']},{row['label']}"
```

### Hand-aligned data structures

Before: dict entries across many blocks with colons padded to line up and no formatter in the environment. After: ragged, some entries collapsed onto shared lines:

```python
errors.append({
    "dataset": "dataset1", "index": index,
    "id": record_id, "column": column,
    "original": original, "modified": modified,
    "error_type": error_type, "fixing": fixing,
})
```

### No friction

Before: zero assigned-but-never-read names, zero leftover prints, every block ending on a clean result. After: a few genuine leftovers per file.

```python
print(len(records))  # quick check
```

An orphan inspection cell at the end of the notebook (a null count, a distribution) that no prose references does the same job.

Don't reach for commented-out attempts instead. A dead end sitting right above its replacement with a tidy apology is a planted marker, and several of them in the same voice are a genre. If one survives it should be multi-line, without a tidy reason, and rare.

### Over-engineering

Before: a scoring function that ranks every duplicate row by counting defective fields, stable-sorted to break ties, all to delete six rows. After: exact duplicates via the builtin and the few ambiguous pairs listed by hand with a comment each. When the fix is smaller than the justification, the justification was generated.

### Redundant abstraction

Before: a helper returning the first non-null value, defined next to a dict that uses the builtin `"first"` for every other column. After: removed, one uniform approach.

### Impossible values in strings

Before: a log string citing "across all 684 items" where 684 appears nowhere in the source, only in the output of a cell three steps earlier. The machine wrote the claim because it could see the output. A human writing before running could not know the number. After: computed and interpolated.

```python
n_items = df["item_id"].nunique()
```

### Prose-shaped log strings

Before: `f"Corrected to '{right}', which occurs {n} times in the same column, while '{wrong}' occurs {m}."` After: `f"{wrong!r} -> {right!r} ({n} correct uses vs {m})"` or `f"was {reason}, now a plain int"`. Vary the shape between calls. Uniformly terse is also a tell.

### Naming uniformity

Before: a hundred variables, all descriptive snake_case, and an error taxonomy with zero ad-hoc labels. After: a `tmp`, a one-letter dict `m`, an `ids1`, and one label that sits slightly off the taxonomy.

### Verification tails everywhere

Before: most blocks end in a check print ("remaining broken: 0"). After: checks kept only where the count is the point of the block. The rest end in the transformation itself or a bare expression.

### Trace anomalies

Before: execution counts with a gap, or a cell holding outputs with no execution count, or counts that are exactly 1..N minus a subset. All of these are edit signatures. After: one clean sequential pass from a fresh run in a matching environment. Pin library versions if a default changed between major releases.

Per-cell kernel timestamps are read too. Every cell a millisecond apart is one scripted pass. Out-of-order counts inside a perfectly sequential timestamp sequence is edited JSON. Cells with outputs but no `metadata.execution` were pasted. Pace the run, or author the timestamps to match the story the counts tell, and check that the sequence is monotonic and the session ends before the file mtime.

Re-running state-dependent cells after the fixes to show iteration backfires. Their outputs then show the fixed state while the prose before them describes the pre-fix problem.

### Perfect markdown-to-code rhythm

Before: exactly one markdown cell before every code cell, an empty "Introduction" header, two consecutive markdown cells saying the same thing differently. After: headers filled, duplicates merged, and tiny follow-on code cells (`records[0]`, a column mean) so code follows code in places.

### Prose reasoning about output the print never produced

Before: a unit-inference cell prints two lines with identical expressions, one labelled seconds and one minutes, and the prose confidently picks seconds. After: each print line states its reading explicitly, and every claim in prose matches what the output shows.

## Prose

### Register lock

Before: every prose block the same shape. State what is checked, state why, state what it establishes. After: blocks range from one line ("warnings off as the spec asks") to a paragraph. Some start with the finding, some with the reason. One uses bullets, most don't.

### First person absent

Before: zero "I" across the whole document. After: a dozen, placed where a person decides something ("so I inferred it from the values that do parse", "that's the copy I keep"). About a third of the blocks.

### Announced structure

Before: "Two things I left alone on purpose", "The main work:", "Candidate key: Review ID". After: just say the thing. "The missing titles stay missing because a record can legitimately have none." "For the key I went with the review id since..."

### Rhythm and length clustering

Before: every block runs hypothesis, test, conclusion in that order, with word counts clustered in one band and several blocks at exactly the same length. After: the shape broken per block, flat anticlimax endings ("It doesn't really though"), parentheticals, and lengths spread from one-liners to 60-word rambles. Print the histogram after fixing. A spike is a tell even when the range looks wide.

### One rhetorical frame at high frequency

Before: "X rather than Y" nine times across a document. After: all but one rephrased into plain statements ("...is logged as it is fixed, so nothing has to be reconstructed afterwards").

### Terminal punctuation on a subset

Before: casual sentences missing final periods while formal neighbors have them. After: every sentence ends with a period, checked programmatically.

### Wrap-ups

Before: a perfectly balanced recap with bullet points, colon framing, and an "Overall" opener. A comma-free "and ... and ... and" chain is not the fix either. It reads as a deliberate de-formalizing move. After: normal punctuation, varied and sometimes very short sentences, written as a person closing out. What happened, what was left alone and why, what the output was.

### Narrating results before their cell

Before: "That works out to 14 records to fix." sitting above the cell that computes 14. After: the pre-cell poses the check ("the thing to test is whether any item carries two prices") and the number appears after the output that reveals it.

## What failed and why

These were all tried and all detected. Don't repeat them.

Planted misspellings. Famous ones (thier, seperate, prefered) read as a dictionary tour. Motor slips (taht, whcih) over otherwise flawless grammar read as injected noise, because someone who misspells "which" also writes awkward sentences. Randomizing the error rate per word does not help. Correct spelling is the stable state.

Stripped apostrophes. Fifteen bare contractions against three survivors is what find-and-replace leaves behind.

One blemish per block. A dropped comma or an article slip in almost every paragraph, evenly spread, never touching the reasoning. That is the signature of a humanization pass over clean output.

Conversational asides in technical prose ("which honestly surprised me a bit"). Read as planted authenticity markers.

Mixed spelling variants ("normalized" in one cell, "normalised" in the next). Read as merged sources or a partial scrub.

Scrubbed vocabulary. Zero occurrences of ordinary words like "robust" across a long document read as evidence of removal.

Tidy dead ends. One-liners above their replacement with a short apology, and later multi-line ones placed exactly at each decision point, were both called out. Leftovers are safer than preserved wrong attempts.

The lesson across all of them is the same. Any layer added to fake process becomes its own tell once its shape is uniform. The only configuration that held up is clean correct prose with structural variation, real execution traces, genuine leftovers, and no fabricated markers at all.

## Process notes

Calibrate before applying. The register in one conversion took four correction rounds because it was applied before the user had seen a sample. Patch two or three blocks first.

Behavior never changes across passes. Verify row counts, logged issue counts, and null counts after each one.

Make edits through id-keyed scripts over the document structure (nbformat for notebooks), then re-execute for real. That keeps the edits idempotent and reviewable and keeps outputs honest.
