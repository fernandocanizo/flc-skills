---
name: flc-rocky-reviewer
description: Use when reviewing a topic branch in the Rocky project before merging. Analyzes all modules touched by the changeset as whole files, not diffs. Produces a numbered, severity-tagged report saved to .claude/flc-reviews/<branch>.md.
---

# Rocky Branch Reviewer

## Overview

Full-module code review for topic branches in the Rocky (nexus-client) project. Does **not** diff — reads each affected file in full, then cascades to dependencies when issues are found.

**Core principle:** Review the code as it exists today, not what changed. The codebase predates AI tooling and has established patterns that must be understood in context.

## When to Use

- You are on a topic branch (not `main` or `dev`)
- The branch contains work from your team that needs review before merging
- You want a structured, referenceable report you can discuss issue-by-issue

## Workflow

### Step 1 — Guard

```bash
git branch --show-current
```

If the result is `main` or `dev`: **stop immediately**. Reviews only happen on topic branches.

Save the branch name — it will be used for the report filename.

### Step 2 — Find the base commit

```bash
.claude/skills/flc-rocky-reviewer/scripts/find-first-merge-commit.sh
```

This script prints the hash of the last "Merge pull request" commit, which is the last PR that landed on `dev` before this branch started. It is used directly as the diff base — no parent navigation needed. Save the printed hash as `MERGE_COMMIT`.

> **Note:** If the repo uses a different merge message format (not "Merge pull request"), adjust the `grep` pattern inside the script accordingly.

### Step 3 — Get the file list

```bash
git diff-tree --no-commit-id --name-only -r ${MERGE_COMMIT}..HEAD
```

`MERGE_COMMIT..HEAD` = all files changed going from the merge base to the tip of the current branch. Save this list — these are the files to review.

> **If you are making code changes during or after this review (not just reading):**
> At the end of each batch of changes, run:
> - `pnpm check:types` — TypeScript strict mode
> - `pnpm check:locales` — validates translation completeness across en/es/pt
> - `pnpm check:lint` — Biome linting
> These are covered by git hooks on commit, but running them mid-session catches issues earlier.

### Step 3b — Graph-assisted triage (code-review-graph)

Before reading any files, run two graph tools to get a risk-scored overview:

1. **`detect_changes`** — pass the commit range `${MERGE_COMMIT}..HEAD`. This returns a risk-scored list of changed nodes (functions, components, modules). Use the scores to prioritize which files deserve the closest scrutiny.
2. **`get_impact_radius`** — for any node flagged HIGH risk by `detect_changes`, check its blast radius. This surfaces hidden dependents that the cascade step (Step 4.5) might otherwise miss.

These tools are fast and token-cheap. Do not skip them — they inform the order and depth of Step 4.

### Step 3c — URL search param audit

If any changed file reads or writes URL search params (`searchParams.get/getAll/.has()`, `params.append/set()`, `URLSearchParams`, or link `?key=value` construction), check each param name against this catalog:

`alarmed`, `bound`, `byStat`, `clone`, `dateFromPlot`, `dateToPlot`, `endDate`, `find`, `generation`, `handler`, `ht`, `inc_interval`, `inc_range`, `inc_ts_from`, `inc_ts_to`, `interval`, `isBillingRead`, `isClient`, `isDemandRead`, `isRegexp`, `isTenant`, `lat`, `limit`, `listener`, `login`, `long`, `password-reset`, `read_interval`, `read_ts_from`, `read_ts_to`, `return-to`, `role`, `selectedGroupId`, `session-expired`, `skip`, `sort`, `startDate`, `stat`, `state`, `tenant`, `ts`, `up`, `usagePlan`, `z`

For any param **not** in this list (new param) or that looks misused (wrong reader, wrong writer, wrong route): read `doc/url-search-parameters.md` for the full contract and add a finding.

---

### Step 4 — Per-file deep analysis

For each file in the list (ordered by risk score from Step 3b, highest first):

1. **Use `get_review_context`** to get source snippets for the file — this is the default. Fall back to reading the full file only when the snippet is insufficient for a confident review judgment.
2. **Invoke the `code-simplifier` agent** — focuses on clarity, consistency, and maintainability
3. **Apply systematic-debugging mindset** — look for:
   - Data flow assumptions that could break silently
   - State that is set in one place and read in another with no synchronization
   - Error paths that are swallowed or ignored
   - Loader/action patterns that diverge from how the rest of the app does similar things
   - Missing or incorrect TypeScript types (especially `any`, untyped GraphQL responses)
4. **Check Rocky-specific patterns:**
   - GraphQL queries must use `getGqlFetcher` — no raw fetch calls to the backend
   - No client-side state management libraries (no Redux, Zustand, etc.) — Remix loaders/actions only
   - Translations must exist in all three locales (en, es, pt) — flag any new UI strings not covered
   - Button active states must scale to 90% and show a spinner when loading (per `doc/style.rules.md`)
   - Icons must be monochrome outline, 16px/1rem, positioned before text
   - Menu items that open dialogs must end with `…`
   - Forms must support implicit Enter submission
5. **Cascade** — if a file imports from or delegates to another module that looks suspect, read that module too and include it in the analysis. Document which files were added via cascade vs. the original list.

### Step 5 — Write the report

Write the report directly to `.claude/flc-reviews/<branch-name>.md` without asking for confirmation and without creating the folder, it's already there. Only attempt to create the folder if writing the report fails. When done, tell the user the report is ready and its path. Do not summarize the findings inline — the file is the output.

**Format:**

```markdown
# Review: <branch-name>
**Date:** <date>
**Files in changeset:** <N> original + <M> cascaded
**Total issues:** <N> CRITICAL / <N> WARNING / <N> SUGGESTION

---

## Summary

<2-4 sentence overall assessment. Call out the most important finding.>

| # | File | Severity | Synopsis |
|---|------|----------|----------|
| 1 | ... | CRITICAL | ... |
| 2 | ... | WARNING  | ... |

---

## Findings

### Issue #1 — [CRITICAL] Title
**File:** `path/to/file.tsx` line N
**Description:** ...
**Why it matters:** ...
**Suggestion:** ...

### Issue #2 — [WARNING] Title
...
```

**Severity definitions:**
- `CRITICAL` — likely to cause a bug, data loss, security issue, or runtime failure
- `WARNING` — violates project conventions, will cause confusion, or is a latent problem
- `SUGGESTION` — clarity, maintainability, or style improvement

**Append subsequent discussion** to the same file — do not overwrite. New issues discovered during discussion get new numbers (continuing from where the initial report left off).
