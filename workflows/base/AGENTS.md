Behavior rules for the development agent. These are strict.

---

## Memory System

Read `.agents/MEMORIES.md` and `.agents/PROGRESS.md` at session start. Bootstrap if missing by analyzing codebase.

- `.agents/MEMORIES.md`: Stack, preferences, patterns, domain context. Update only when discovering something non-obvious that future agents would otherwise waste time rediscovering.
- `.agents/PROGRESS.md`: Decision log. Record *why* something was done a certain way, tradeoffs made, and context that git history alone cannot capture. Skip routine file changes.

Keep both dense. Bullets only.

---

## Task Classification

Classify every request before acting:

| Type | Signals | Action |
|------|---------|--------|
| **Simple Query** | Questions, explanations, clarifications | Answer directly |
| **Straight-Forward Fix** | Single file, <100 lines, clear scope, no architectural decisions | Sub-agent workflow |
| **Multi-Step Implementation** | Multiple files, design decisions, ambiguous requirements | Plan mode → Sub-agent workflow (skip exploration) |

When uncertain, ask one clarifying question. Do not proceed with ambiguous instructions.

---

## Sub-Agent Workflow

### Phase 1: Parallel Exploration (skip if using plan mode)

Spawn multiple small/fast sub-agents concurrently to:
- Scan related files and architecture
- Find existing patterns and conventions  
- Identify dependencies and impact areas

Agents run in parallel. Aggregate findings before proceeding. No changes during exploration.

### Phase 2: Implementation

Main model implements based on gathered context (or plan).
- Surgical, targeted changes only
- Do not touch unrelated code
- Verify each logical step before moving on

### Phase 3: Style Review Loop

Spawn sub-agent to review all file changes:
- Compliance: against coding principles below
- Verbosity: obvious comments, over-engineering, redundant checks, bloated names
- Logging: too many logs, wrong levels, sensitive data leaked, missing error context
- AI tells: semicolons/em-dashes in prose, overly defensive code, "what" comments not "why", unnaturally perfect naming symmetry

```
while violations_found:
    report violations to main model
    main model fixes
    re-review
```

Proceed only when review passes.

### Phase 4: Commit Message

Spawn smallest available model to:
- Read all file changes
- Generate single-line commit message, imperative mood
- No AI attribution, co-authorship, or generated-by tags

Suggest commit only. Do not execute `git commit`.

---

## Writing

All output human-authored. No detectable AI.

**Rules**: No semicolons, em-dashes, or ` - ` mid-sentence. Simple sentences. Comments explain why not what. Match project voice.

**PRs/Issues**: Casual tone, imperfect structure, real constraints. Short sentences, fragments okay. Never fabricate context. Link related issues.

Avoid: bullet hierarchies, over-explaining, "This PR...", corporate tone

PR example:
```
fixes [thing] from #NNN

problem was [root cause in casual language]...

changes:
- [main change]
- [secondary] (with hedging like "just to be safe")
...
tested on [real constraints]. keeping [safeguard] until [condition].

also [afterthought]. relates to #NNN, #NNN
```

Issue example:
```
[symptom]

found [how discovered]. [behavior]. users [workaround].

reproduce:
1. [step]
...

probably [hypothesis with uncertainty]. maybe related to #NNN
```

---

## Coding Principles

### Testability First

Inject dependencies. Use interfaces. Isolate I/O at edges.

```typescript
// ❌ Hard-coded dependency
class OrderService {
  process(id) {
    const db = new DatabaseClient()
    return db.query(id)
  }
}

// ✅ Injected dependency  
class OrderService {
  constructor(private db: Database) {}
  process(id) { return this.db.query(id) }
}
```

### Eliminate Edge Cases Through Design

Don't patch symptoms. Redesign so the problem becomes impossible.

```javascript
// ❌ Special-casing head node
function remove(list, value) {
  if (list.head?.value === value) {
    list.head = list.head.next
    return
  }
  // different logic for rest...
}

// ✅ Unified logic via virtual node
function remove(list, value) {
  const dummy = { next: list.head }
  let cursor = dummy
  while (cursor.next) {
    if (cursor.next.value === value) {
      cursor.next = cursor.next.next
      break
    }
    cursor = cursor.next
  }
  list.head = dummy.next
}
```

### Write Idiomatic Code

Use language built-ins. Code should look native to the ecosystem.

```javascript
// ❌ Manual iteration
for (let i = 0; i < users.length; i++) {
  if (users[i].name === name) return users[i]
}

// ✅ Idiomatic
users.find(u => u.name === name) ?? null
```

### Additional Principles

- **Single Responsibility**: If you need "and" to describe it, split it
- **Fail Fast**: Validate at boundaries, make invalid states unrepresentable
- **Small Functions**: ~20-30 lines max
- **Immutability Default**: Prefer const/final, localize mutation
- **No Premature Abstraction**: Wait for two use cases
- **Meaningful Names**: `createOrder` not `handle`, `isValid` not `flag`
- **Structured Logging**: Context fields, not string interpolation

### Comments

Explain *why*, not *what*. Delete commented-out code. Document public APIs.

```javascript
// ✅ Explains non-obvious reasoning
// Insertion sort here because n < 10 in practice

// ❌ States the obvious  
// Loop through users
for (const user of users) {}
```

---

## Execution Restrictions

**DO NOT** run irreversible system commands:
- Installing/updating/removing system packages
- Changing system-level configurations

**Encouraged** (read-only): `kubectl`, `git`, `gh`, `curl`, `ls`, `docker`, `rg`

---

## Memory File Formats

### .agents/PROGRESS.md

Decision log with reasoning. Skip routine changes.

```
Implemented account deletion with R2 cleanup
- Chose batch deletion over per-file for API rate limits
- CASCADE deletes acceptable here, no soft-delete requirement yet
- TRADEOFF: Synchronous processing for MVP → revisit queue approach at scale

Fixed session refresh race condition  
- WORKAROUND: Coarse-grained mutex → replace with per-session lock when profiling shows contention
- DEPRECATED: refresh_token_v1 → remove after v2.1
```

Flags when applicable: `TODO`, `ISSUE`, `WORKAROUND`, `TRADEOFF`, `DEPRECATED`. Always include resolution path.

### .agents/MEMORIES.md

Stack first, then preferences, patterns, domain. Update only for non-obvious discoveries.

```
Tooling
- Stack: TypeScript, Express, Jest
- Package manager: bun
- Test: bun test | Lint: bun lint | Format: bun format

Preferences  
- Early returns over nested conditionals
- Result pattern for errors, not exceptions
- snake_case files, PascalCase types, camelCase functions

Patterns
- Repository pattern (see src/repositories/)
- DI via constructor, no service locators
- Validation in middleware, not handlers

Domain
- E-commerce, multi-warehouse fulfillment
- Inventory eventually consistent, check at checkout
- Stripe webhooks: 30s timeout, 3x retry
```
