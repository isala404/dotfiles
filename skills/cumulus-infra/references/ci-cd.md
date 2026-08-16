# CI/CD

Two workflows per app, one registry, one image repo. The **tag prefix is the only thing separating dev from prod.**

| | Stage | Release |
|---|---|---|
| Trigger | push to `main`, path-filtered | push of a `v*` tag |
| Tag | `dev-${{ github.run_id }}` | `prod-${{ github.run_id }}` |
| Gate | sign-off note already on the commit | `verify` job runs lint + tests + E2E |
| Caching | full | **none, deliberately** |
| Concurrency | one group, `cancel-in-progress: true` | per-ref, never cancelled |
| Extra | step summary | `gh release create --verify-tag --generate-notes` |

Path filters matter: the stage workflow only fires when the backend crates, `Cargo.lock`, the toolchain file, or the workflow itself changed. Touching unrelated paths produces no image, and that is not a failure.

## Tag both prefixes with `github.run_id`

Dev and prod differ by prefix only. **Both use `github.run_id` as the numeric part**, never `run_number` or the git tag name.

`run_id` is globally unique and monotonically increasing across every workflow in the repo, which is exactly what the cluster's ImagePolicies need: they filter `^(dev|prod)-(?P<number>\d+)$` and order `numerical`, picking the highest. `run_number` is per-workflow and resets when a workflow is recreated, which strands the policy on an old tag. A semver git tag (`prod-v1.2.0`) isn't a number at all and matches the filter zero times. The automation then does nothing, silently, which reads exactly like a broken pipeline.

So a release tags `prod-${{ github.run_id }}`, not `prod-${{ github.ref_name }}`. The git tag still identifies the release through `gh release create`; it just isn't the image tag.

Point the dev overlay's policy at the `dev-` prefix and the prod overlay's at `prod-`. Never point one policy at both because it would promote a dev build into production the moment its run id won.

Promotion is cutting a tag, which triggers a fresh clean build. It is not retagging or moving an existing image.

## Build on the runner, inject into the container

Both workflows compile a **static musl binary on the runner** and hand the output directory to Docker as a named build context, rather than building inside Docker:

```yaml
- uses: dtolnay/rust-toolchain@stable
  with: {toolchain: <pinned>, target: x86_64-unknown-linux-musl}
- run: sudo apt-get install -y musl-tools
- run: just build-backend-binaries dist "$GITHUB_SHA"

- uses: docker/build-push-action@v7
  with:
    target: runtime
    build-contexts: binary=dist
    tags: ${{ env.IMAGE }}:dev-${{ github.run_id }}   # prod- on the release workflow
```

The compile is `cargo build --locked --release --target x86_64-unknown-linux-musl`, then `strip`, then copy to `dist/`.

musl matters twice over: it links statically, so the runtime image needs no glibc and can be plain Alpine; and since runners are already x86_64 Linux this is a libc swap, not cross-compilation. `musl-tools` plus the rustup target is the entire setup.

The Dockerfile carries a `binary` stage that CI **replaces** via `build-contexts: binary=dist`, so `COPY --from=binary` picks up the runner-built artifact. Its `chef`/`planner`/`build` stages exist only for local Docker-only builds and never execute in CI, because `target: runtime` skips straight past them. Runner-side incremental caching beats Docker layer caching for this, which is the whole reason for the arrangement. Don't "simplify" it by building in Docker.

Runtime stage: Alpine, `ca-certificates`, a non-root user at a fixed high uid, binaries under `/app`, `USER` set before `CMD`. That non-root user is what satisfies the cluster's `runAsNonRoot` requirement.

## Caching, and why release has none

Stage uses `Swatinem/rust-cache@v2` with a `shared-key` naming the target profile and `cache-targets: true`. Per-crate granularity survives dependency churn far better than a whole-target cache.

Release deliberately has **no cache at all**: no `rust-cache`, plus `no-cache: true` on the Docker build. A release must be reproducible from source rather than risk a stale or poisoned cache entering a production image. It is slower on purpose; don't "fix" it.

No `cache-from`/`cache-to` on the Docker build in either workflow. The binary is pre-built, so there is nothing worth exporting.

## Registry auth by OIDC

No stored registry credentials anywhere. The job requests a GitHub-signed OIDC token scoped to the registry as audience, POSTs it to a small in-cluster broker, and gets back short-lived registry credentials. Requires `permissions: {id-token: write}`.

```bash
token=$(curl -sf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=<registry>" | jq -r '.value')
response=$(curl -sf -X POST https://<broker>/v1/github-oidc/token \
  -H "Content-Type: application/json" -d "{\"token\": \"$token\"}")
password=$(echo "$response" | jq -r '.password')
echo "::add-mask::$password"
echo "username=$(echo "$response" | jq -r '.username')" >> "$GITHUB_OUTPUT"
echo "password=$password" >> "$GITHUB_OUTPUT"
```

The broker validates the token's repo and ref claims and mints credentials scoped to an allowlist of organizations. `::add-mask::` goes on the password the moment it exists, before it reaches `$GITHUB_OUTPUT`. The username isn't sensitive and isn't masked. The block is duplicated verbatim in both workflows; there is no shared composite action.

## Gates

**Stage doesn't run the test suite.** It verifies a git note exists on the pushed commit, written by a local sign-off script that runs lint, tests, and the full E2E suite, requires a clean working tree, and re-checks that `HEAD` and cleanliness didn't move while it ran. The expensive gate lives on the developer's machine; CI checks the receipt.

The note lives on its own ref and **must be pushed separately from the branch**. The usual failure is a developer pushing the commit but not the note, which fails the build with an annotation telling them what to run.

**Release runs the real gate in CI**: a `verify` job doing lint, unit tests, and E2E, with test artifacts uploaded on failure only. The build job depends on it and re-checks-out rather than reusing anything from `verify`.

Note what this means: a push to `main` never proves anything in CI. If you need CI-verified assurance, cut a tag.

## Things the build depends on

- `SQLX_OFFLINE=true` and a **committed `.sqlx/` query cache**. Without both, the sqlx macros try to reach a live database at compile time and the build fails with a confusing connection error. Regenerating the cache is a separate recipe that spins up a throwaway Postgres.
- `Cargo.lock`, because everything uses `--locked`.
- The toolchain is pinned in `rust-toolchain.toml` *and* again in the workflow. Belt and braces: change both or neither.
- `just` is the build interface. Workflows call recipes; they don't inline cargo commands. Change the recipe, not the workflow.
- The mold linker is incompatible with Alpine musl on x86_64.
- The build-revision arg sits *after* the dependency-cook step in the Dockerfile so a new commit SHA can't invalidate the dependency layer. Preserve that ordering.
