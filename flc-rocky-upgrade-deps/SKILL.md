---
name: flc-rocky-upgrade-deps
description: "Trigger: /flc-rocky-upgrade-deps, upgrade dependencies, update deps, dependency upgrade. Layered pnpm campaign for Rocky (nexus-client): outer tooling first, React/React Router last, runs end to end unasked."
license: MIT
metadata:
  author: "fernandocanizo"
  version: "1.0"
---

# Rocky Dependency Upgrade

## Activation Contract

Rocky (nexus-client) repo only — confirm via `package.json` name. Triggers: `/flc-rocky-upgrade-deps`, "upgrade dependencies", "update deps". Run the whole campaign end to end unasked; only stop for the forks under Hard Rules.

## Hard Rules

- Peer-range compatibility is not proof a bump is safe. For any major, or a wide minor jump, WebFetch the package's migration guide/changelog before touching code.
- Packages already peer-locked to each other bump together, never split.
- If a dep needs a peer floor on another (router needing a React version) not yet met, bump both as one combined layer.
- A major that's really a full API rewrite: prefer the library's own compat/legacy shim over a repo-wide rewrite; full migration only if no shim exists or the user explicitly asks. Record what's deferred.
- After every layer: `pnpm fixall && pnpm check:types && pnpm check:lint`, then full `pnpm test`. Never batch verification across layers.
- Framework-level layers (router, UI framework, build pipeline): also `pnpm build` and boot the app for a real smoke test. Type checks and unit tests alone aren't proof here.
- Run `./run-e2e` once before declaring done. Never open/edit `run-e2e`. On failure, rule out stale state (stray dev-server processes, `node_modules/.vite`) before calling it a regression.
- Credentials surfacing in any tool output never get written to a file, commit message, or memory.
- Never `git add`/stage/commit — stays the user's call.
- An unrelated bug found along the way: write `docs/issue-<slug>.md`, don't fix inline, don't auto-file via `gh`.

## Decision Gates

| Layer | Contents | Granularity |
|---|---|---|
| 0 | Leaf tooling, no React coupling | Batch: one install + verify |
| 1 | React-adjacent leaves already covering the target React major | Batch: one install + verify |
| mid | Peer-locked pairs; majors with real API surface | One bump + verify + commit-msg each |
| final | React + router + anything peer-floored to them | Combined, most rigorous verification |

Node/runtime bumps are a separate concern, out of scope.

## Execution Steps

1. `mem_search`/`mem_context` for prior campaign state, deferred items, known gotchas.
2. `pnpm outdated --format json` for the full candidate list.
3. Classify each candidate into the layer table, checking peer ranges as needed.
4. Per layer, least to most risky: edit `package.json`, `pnpm install`, verify per Hard Rules.
5. Fix type/lint errors with the narrowest correct change — read what the new type requires before widening or casting.
6. After each layer, overwrite `docs/commit-msg` (present-tense); check `git log`/`git status` first — merge into one message if prior layers are still uncommitted.
7. `mem_save` a checkpoint per layer under one topic key so the campaign resumes if interrupted.
8. After the final layer, run `./run-e2e` per Hard Rules.

## Output Contract

Report every package bumped (old -> new) by layer, every verification command with pass/fail, deferred/known-debt items, any `docs/issue-*.md` filed, and confirmation nothing was staged or committed.

## References

None — self-contained; Rocky conventions are restated above since this skill lives outside that repo.
