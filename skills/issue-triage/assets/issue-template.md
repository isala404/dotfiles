Title (goes in `--title`, not in the body): a short, specific line naming the outcome you want. Examples:

* `Prevent expired sessions from being refreshed`
* `Return 404 when a project does not exist`
* `Retry transient upload failures in the worker`

The body starts here:

## Problem

<What is wrong, missing, risky, or unnecessarily complex? Include the observed behaviour and why it matters.>

## Expected change

<Describe the desired behaviour or implementation outcome. Avoid prescribing the exact implementation unless required.>

## Scope

* **Relevant code:** `<files, modules, functions, or symbols>`
* **In scope:** `<required changes>`
* **Out of scope:** `<related work that must not be included>`
* **Preserve:** `<behaviour, APIs, compatibility, or architectural constraints>`

## Done when

* [ ] `<observable success criterion>`
* [ ] `<important edge case>`
* [ ] Tests cover the changed behaviour
* [ ] Existing tests and checks pass
* [ ] No unrelated refactoring or behaviour changes

## Verification

```sh
<commands the implementation agent should run>
```

## Evidence

<Error, code reference, reproduction steps, logs, or links. Remove this section when unnecessary.>
