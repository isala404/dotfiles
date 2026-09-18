#!/usr/bin/env python3
"""Mechanical AI-tell scanner for documents and code.

Reports the properties that fingerprint machine authorship. Run it before and
after a de-AI pass and compare against the register calibration the user chose:
the goal state is that calibration, not any absolute number.

Usage:
    python audit_tells.py FILE [FILE ...]

Supports .py, .md, .ipynb (if nbformat is installed) and treats anything else
as plain text. Exit code is always 0; read the report, don't script against it.
"""

import math
import re
import sys
from collections import Counter
from pathlib import Path

AMERICAN = {"ize", "ized", "izing", "ization", "yze", "yzed", "or", "ers"}
BRITISH = {"ise", "ised", "ising", "isation", "yse", "ysed", "our", "ours"}


def load_cells(path: Path):
    """Return (code_text, prose_text) for a file."""
    text = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix == ".ipynb":
        try:
            import json
            nb = json.loads(text)
        except json.JSONDecodeError:
            return text, ""
        code, prose = [], []
        for cell in nb.get("cells", []):
            src = "".join(cell.get("source", []))
            (code if cell.get("cell_type") == "code" else prose).append(src)
        return "\n".join(code), "\n".join(prose)
    if path.suffix == ".py":
        return text, ""
    if path.suffix in {".md", ".markdown", ".rst", ".txt"}:
        return "", text
    return text, ""


def report_code(code: str, out: list):
    if not code.strip():
        return
    lines = code.splitlines()
    singles, doubles = code.count("'"), code.count('"')

    standalone, inline = [], []
    for ln in lines:
        s = ln.strip()
        if s.startswith("#"):
            standalone.append(s)
        elif "#" in s and not s.startswith('#"'):
            # crude: a # after code, ignore strings containing # (acceptable noise)
            m = re.search(r"#\s*(.+)$", ln)
            if m and not re.search(r"[\"'].*#.*[\"']", ln):
                inline.append(m.group(1).strip())

    punctuated = sum(1 for c in standalone + inline
                     if re.search(r"[.,;:!?]", c.rstrip()))
    avg_len = (sum(len(c.split()) for c in standalone + inline) /
               max(1, len(standalone) + len(inline)))

    out.append("  code")
    out.append(f"    quote chars            double={doubles} single={singles} "
               f"ratio={doubles / max(1, doubles + singles):.2f}")
    out.append(f"    comments               standalone={len(standalone)} inline={len(inline)} "
               f"(tell if standalone >> inline)")
    if standalone + inline:
        out.append(f"    comment grammar        punctuated={punctuated} "
               f"({100 * punctuated / (len(standalone) + len(inline)):.0f}%) "
               f"avg_words={avg_len:.1f}")
    debris = sum(1 for l in standalone if re.search(r"\w\s*=\s*\S", l))
    attempts = sum(1 for l in standalone if re.match(r"#\s*\w", l) and ("=" in l or "(" in l))
    out.append(f"    commented-out code     {debris} assignments + {attempts} noted attempts")
    lazy = len(re.findall(r"^\s{0,8}[a-z]\s*=[^=]", code, re.M))
    df2 = len(re.findall(r"\bdf2\b", code))
    out.append(f"    lazy names             tmp={code.count('tmp')} "
               f"df2={df2} single-letter assigns={lazy}")

    # aligned-colon blocks: 3+ consecutive lines with ':' at the same column
    aligned = 0
    run = Counter()
    for ln in lines:
        col = ln.find(": ")
        if col > 0 and not ln.strip().startswith("#"):
            run[col] += 1
        else:
            aligned += sum(1 for v in run.values() if v >= 3)
            run = Counter()
    aligned += sum(1 for v in run.values() if v >= 3)
    out.append(f"    aligned-colon blocks   {aligned}")

    # all-caps MUST-style instructions and TODO debris (context, not tells)
    verif = len(re.findall(r"print\(.*(remaining|still|valid|duplicated|logged)", code))
    out.append(f"    verification prints    {verif}")


def sentences(prose: str):
    for para in re.split(r"\n\s*\n", prose):
        para = para.strip()
        if not para or para.startswith(("#", "- ", "* ", "|")):
            continue
        for s in re.split(r"[.!?]\s+", para.replace("\n", " ")):
            s = s.strip()
            if s:
                yield s


def report_prose(prose: str, out: list):
    if not prose.strip():
        return
    blocks = [b for b in re.split(r"\n\s*\n", prose) if b.strip()]
    words = len(prose.split())
    first_person = len(re.findall(r"\b(I|my|me|mine)\b", prose))
    bullets = len(re.findall(r"^\s*[-*]\s+", prose, re.M))
    headings = len(re.findall(r"^#{1,6}\s", prose, re.M))
    sents = list(sentences(prose))
    slens = [len(s.split()) for s in sents]
    colons = prose.count(":")
    commas, fullstops = prose.count(","), prose.count(".")

    # spelling variant mixing: look for -ise/-ize style pairs
    ized = len(re.findall(r"\w+iz(e|ed|ing|ation)\b", prose))
    ised = len(re.findall(r"\w+is(e|ed|ing|ation)\b", prose))

    # announced-structure and stage-management phrases
    staged = [p for p in (r"^\s*(The )?(main|rest|real) (work|point)",
                          r"^\s*(Two|Three|Four) things\b",
                          r"^\s*Overall\b", r"^\s*In (conclusion|summary)\b",
                          r"^[^.\n]{0,40}:\s*$")
              for ln in prose.splitlines()
              if re.search(p, ln, re.I)]
    # length-1 sentence scan (sorted spans of >=3 chars)
    long_words_ratio = sum(1 for w in prose.split() if len(w) > 8) / max(1, words)

    out.append("  prose")
    out.append(f"    blocks={len(blocks)} words={words} headings={headings}")
    out.append(f"    first person           {first_person}  (0 across many blocks is a tell)")
    out.append(f"    bullet lines           {bullets}")
    if slens:
        med = sorted(slens)[len(slens) // 2]
        mean = sum(slens) / len(slens)
        spread = (sum((n - mean) ** 2 for n in slens) / len(slens)) ** 0.5
        out.append(f"    sentences              n={len(slens)} min={min(slens)} median={med} "
                   f"spread={spread:.1f}")
        short = [s for s, n in zip(sents, slens) if n < 8]
        if short:
            out.append(f"    short sentences (<8w)  {len(short)}  e.g. {short[:2]!r}")
    out.append(f"    colons={colons} commas={commas} fullstops={fullstops} "
               f"(uniform zero-across-artifact is itself a tell; match calibration)")
    out.append(f"    spelling variants      ize-family={ized} ise-family={ised} "
               f"{'MIXED' if ized and ised else 'uniform'}")
    out.append(f"    staged-structure lines {len(staged)}")
    out.append(f"    latinale density       long-word ratio={long_words_ratio:.2f}")


def main(paths):
    for p in map(Path, paths):
        code, prose = load_cells(p)
        out = [f"\n{p.name}  ({p.suffix})"]
        report_code(code, out)
        report_prose(prose, out)
        print("\n".join(out))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1:])
