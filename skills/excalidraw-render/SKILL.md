---
name: excalidraw-render
description: Use when asked to draw or diagram something, such as architecture, data flow, sequence, call chain, an ASCII sketch to clean up, or an existing .excalidraw to edit. Outputs an editable .excalidraw plus a PNG.
---

# Excalidraw render skill

**Requires:** `npx` (Node) and network access on the first run, which fetches `@swiftlysingh/excalidraw-cli`. Also needs the ability to spawn a sub-agent because the cost model below depends on it. If sub-agents are unavailable in this harness, say so and offer to author the JSON directly at higher token cost rather than silently doing it.

Make a polished Excalidraw diagram from a rough input, without baby-sitting. The main agent thinks in pixels (by looking at rendered PNGs); a Haiku sub-agent does the JSON work.

**Scope:** draw what the user described, at the level of detail they gave. Don't add components they didn't mention because the architecture "should" have a cache or a load balancer, don't expand a three-box sketch into a full system map, and don't redesign their architecture while diagramming it. If something in the input is genuinely ambiguous, draw your best reading and say what you assumed.

---

## Core principle: cost discipline

A `.excalidraw` file is huge: a 10-box diagram is 3K to 5K tokens. Reading or editing it with the main model is wasteful and slow. Vision on a rendered PNG is far cheaper and far more accurate for layout judgment.

**The main agent MUST:**
- ✅ Read the rendered PNG to judge correctness (this is what vision is for)
- ✅ Plan layouts up-front (positions, sizes, colors) as an architectural judgment
- ✅ Critique specific visual issues from the PNG (overlaps, clipping, misalignment)
- ✅ Dispatch surgical fix instructions to a Haiku sub-agent

**The main agent MUST NOT:**
- ❌ Read the `.excalidraw` JSON file; delegate to Haiku
- ❌ Write the `.excalidraw` JSON inline; delegate to Haiku
- ❌ Hand-edit the JSON; delegate to Haiku
- ❌ Loop forever; hard cap at **3** render and critique cycles

---

## Workflow

```
User input (ASCII / description / sketch)
        │
[MAIN]  Plan layout                ← architectural judgment
        │
[HAIKU] Write diagram.excalidraw   ← author the JSON
        │
[BASH]  npx excalidraw-cli convert  ← produce PNG
        │
[MAIN]  View the PNG               ← visual judgment
        │
   Issues? ── yes ──► [HAIKU] Apply specific fixes ──┐
        │                                             │
       no                                             │
        │                                             │
   Present to user      ◄────────────────────────────┘
                                (max 3 cycles)
```

---

## Step 1: Plan the layout (main agent)

Before any tool calls, decide:

1. **Components:** what shapes (rectangles, diamonds, ellipses) and what each says
2. **Layout family:** vertical flow, horizontal pipeline, hub-and-spoke, or 3-column data flow
3. **Coordinates:** give every shape an exact `(x, y, width, height)` using the Sizing Rules
4. **Colors:** pick from the palette by role
5. **Connections:** list arrows as `(from_id → to_id, label, style)`
6. **Zones / titles / annotations:** optional backgrounds, headers, side labels

Write this as a plain-text **layout brief**. NOT JSON. Haiku will produce the JSON.

**Preserve all detail from the user's input.** If the ASCII says "Fail = Stop & Notify", that label appears verbatim. Don't summarize. Resize boxes to fit the full text.

---

## Step 2: Hand off to Haiku to author the JSON

Spawn a sub-agent on the Haiku model. Pass it the layout brief, the output path, **and inline the Schema Cheat Sheet below** so it doesn't have to guess.

**Sub-agent prompt template (author):**

```
You are authoring a valid Excalidraw scene file. Output the complete JSON to:
  <ABS_PATH>/diagram.excalidraw

# Layout brief
<paste the brief from Step 1, including every shape with exact x/y/w/h, every arrow, and every label>

# Schema cheat sheet
<paste the "Schema cheat sheet" section from this skill verbatim>

# Rules
- Use only the colors from the palette in the brief.
- Every shape has an `id` so arrows can reference it.
- Labels inside shapes are SEPARATE `text` elements with `containerId` set to the shape's id, AND the shape's `boundElements` includes `{ "type": "text", "id": "<label-id>" }`.
- Arrow labels are SEPARATE `text` elements with `containerId` set to the arrow's id, plus matching `boundElements` on the arrow.
- Set `roughness: 0` everywhere for clean lines.
- Output ONLY the file. No commentary, no fences. Make sure it parses with `JSON.parse`.
```

The main agent does NOT review the resulting JSON. Trust Haiku and move on to rendering.

---

## Step 3: Render

```bash
npx @swiftlysingh/excalidraw-cli convert <path>/diagram.excalidraw --format png -o <path>/diagram.png --scale 2
```

No setup is needed because `npx` handles installation on first run. It uses `@excalidraw/utils` under the hood (via jsdom + resvg-js), with no headless browser required. If rendering fails for a large file, spawn a Haiku to summarize what's in the file (Haiku reads it, main agent never does) before fixing.

---

## Step 4: Look at the PNG and critique

Read the PNG (image files render visually). Walk this checklist and write down concrete fixes in pixel / id terms:

| Check | What to look for | Fix instruction to Haiku |
|---|---|---|
| Overlap | Two shapes touch or cross | "Move shape `<id>` to `(x, y) = (...)`." |
| Clipped arrow label | Label cut into a shape or smudged | "Increase gap between `<a>` and `<b>` to 180px (set `<b>.x` to ...)." |
| Text overflow | Label spills outside the box | "Set `<id>.width = 240` (or shorten label to '...')." |
| Cramped zone | Zone background hugs children | "Resize zone `<id>` to `(x,y,w,h) = (...)`." |
| Off-balance | Content piled to one side | "Shift columns: rebalance to center on x=400." |
| Missing title / layer labels | No header; layers unlabeled | "Add text at `(x,y)`, content '...', fontSize 24." |
| Wrong arrow target | Arrow points to wrong box | "Change arrow `<id>`'s `endBinding.elementId` from `X` to `Y`." |
| Wrong color for role | DB shown blue, API green, etc. | "Recolor `<id>` to `bg=#b2f2bb stroke=#2f9e44` (Database role)." |

**Main agent describes WHAT needs to change in pixel/id terms; Haiku reads the file and applies it.** Don't try to compute every coordinate yourself for more than 2-3 elements. Let Haiku do bulk edits.

---

## Step 5: Hand off fixes to Haiku

**Sub-agent prompt template (fix):**

```
Edit the existing Excalidraw scene at <ABS_PATH>/diagram.excalidraw.

Apply ONLY these changes:
1. <fix #1>
2. <fix #2>
3. <fix #3>

# Schema cheat sheet
<paste the "Schema cheat sheet" section so Haiku knows the structure>

# Rules
- Read the file. Modify only the elements named. Preserve every other field exactly.
- When you move a shape, ALSO move its label text element (same containerId) by the same delta so they stay aligned.
- When you resize a shape, recompute the label element's x/y/width to stay centered.
- Write back to the same path. The result MUST parse with `JSON.parse`.
- Output ONLY the path of the file you wrote. No commentary.
```

Re-render and re-view. **Hard cap: 3 cycles total.** After cycle 3, present what you have and list any remaining issues explicitly. Don't loop more because the user can take it from there.

---

## Step 6: Present

Give the user both paths, `diagram.excalidraw` (editable, drag into excalidraw.com) and `diagram.png` (the image), plus a two-line summary of what the diagram shows and any issue you couldn't resolve inside the cycle cap. Don't paste the JSON.

---

## Schema cheat sheet  *(copy-paste this into Haiku prompts)*

**Scene wrapper:**

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [ /* see below */ ],
  "appState": { "viewBackgroundColor": "#ffffff", "gridSize": null },
  "files": {}
}
```

**Rectangle / ellipse / diamond:**

```json
{
  "id": "react-app",
  "type": "rectangle",
  "x": 40, "y": 50, "width": 220, "height": 90,
  "angle": 0,
  "strokeColor": "#1971c2",
  "backgroundColor": "#a5d8ff",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": { "type": 3 },
  "seed": 1, "version": 1, "versionNonce": 1, "isDeleted": false,
  "boundElements": [{ "type": "text", "id": "react-app-label" }],
  "updated": 1, "link": null, "locked": false
}
```

**Text label inside a shape** (separate element, bound by `containerId`):

```json
{
  "id": "react-app-label",
  "type": "text",
  "x": 50, "y": 75,
  "width": 200, "height": 40,
  "angle": 0,
  "strokeColor": "#1e1e1e", "backgroundColor": "transparent",
  "fillStyle": "solid", "strokeWidth": 1, "strokeStyle": "solid",
  "roughness": 0, "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": null,
  "seed": 2, "version": 1, "versionNonce": 2, "isDeleted": false,
  "boundElements": null, "updated": 1, "link": null, "locked": false,
  "fontSize": 18, "fontFamily": 1,
  "text": "React App\nFrontend",
  "textAlign": "center", "verticalAlign": "middle",
  "containerId": "react-app",
  "originalText": "React App\nFrontend",
  "lineHeight": 1.25
}
```

**Arrow** with bindings and a label:

```json
{
  "id": "arrow1",
  "type": "arrow",
  "x": 260, "y": 95,
  "width": 180, "height": 0,
  "angle": 0,
  "strokeColor": "#1971c2", "backgroundColor": "transparent",
  "fillStyle": "solid", "strokeWidth": 2, "strokeStyle": "solid",
  "roughness": 0, "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": { "type": 2 },
  "seed": 3, "version": 1, "versionNonce": 3, "isDeleted": false,
  "boundElements": [{ "type": "text", "id": "arrow1-label" }],
  "updated": 1, "link": null, "locked": false,
  "points": [[0, 0], [180, 0]],
  "lastCommittedPoint": null,
  "startBinding": { "elementId": "react-app", "focus": 0, "gap": 4 },
  "endBinding":   { "elementId": "api-server", "focus": 0, "gap": 4 },
  "startArrowhead": null, "endArrowhead": "arrow",
  "elbowed": false
}
```

`strokeStyle`: `"solid"` (normal) · `"dashed"` (async / optional) · `"dotted"` (weak dependency).

---

## Color palette

| Role | Background | Stroke |
|---|---|---|
| Frontend / UI | `#a5d8ff` | `#1971c2` |
| Backend / API | `#d0bfff` | `#7048e8` |
| Database | `#b2f2bb` | `#2f9e44` |
| Storage | `#ffec99` | `#f08c00` |
| AI / ML | `#e599f7` | `#9c36b5` |
| External API | `#ffc9c9` | `#e03131` |
| Queue / Event | `#fff3bf` | `#fab005` |
| Cache | `#ffe8cc` | `#fd7e14` |
| Decision / Gate | `#ffd8a8` | `#e8590c` |
| Zone / Group | `#e9ecef` | `#868e96` |

Same role → same color. Limit a diagram to **3 to 4 fill colors**.

---

## Sizing rules

The #1 cause of ugly diagrams is **cramping**. When unsure, double the gap.

| Property | Value |
|---|---|
| Box width | 200 to 240px |
| Box height | 80 to 120px (3 to 4 lines comfortable) |
| Horizontal gap, **labeled** arrow | **150 to 200px** |
| Horizontal gap, unlabeled arrow | 100 to 120px |
| Column pitch, labeled | 400px |
| Column pitch, unlabeled | 340px |
| Row pitch | 250 to 300px |
| Font, body | 16 to 18px |
| Font, title | 22 to 28px |
| Font, annotations | 13 to 14px |
| Zone padding around children | 50 to 60px on every side |
| Zone opacity | 25 to 40 |

**Labeled-arrow visibility test:** if the label is more than half the gap between its two boxes, increase the gap. Common offenders such as `"auto deploy"`, `"rollback on failure"`, and `"All pass"` are 100 to 150px wide and clip below ~150px gap.

**Zone sizing rule:** `x = min(child_x) − 50`, `y = min(child_y) − 55`, `w = max(child_right) − x + 60`, `h = max(child_bottom) − y + 60`.

---

## Layout patterns

- **Vertical flow** (default): top→bottom, multi-column. Use for layered architectures and request flows.
- **Horizontal pipeline**: left→right, single row. Use for ETL, transforms.
- **Hub-and-spoke**: central shape at center, others radial. Use for event buses, brokers.
- **3-column data flow**: left = layer names (gray, x<0), center = flow boxes (x: 60 to 360), right = data-form annotations (orange, x: 570+). Use for parameter threading and call-chain traces.

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Main agent read or edited the `.excalidraw` JSON | Stop. Delegate to Haiku. The skill exists to avoid this. |
| Arrow labels clipped | Increase gap between the two boxes to ≥150px |
| Shapes overlap | Move one box by ≥200px; re-check zone bounds |
| Zone hugs its children | Recompute zone box with the Zone sizing rule above |
| Label drifted away from its shape after moving | When Haiku moves a shape, it must move the bound text element by the same delta |
| Dropped detail from user's sample | The sample is the source of truth. Every label verbatim. Resize boxes. |
| Same issue persists 3 cycles in a row | Stop. Present current PNG. List as open issue. Don't loop. |
| Same fix applied twice with no effect | Try a different approach, such as widening the gap or restructuring, instead of retrying the same fix harder. |
| Mixed colors for the same role | One role → one color. Enforce on every iteration. |
