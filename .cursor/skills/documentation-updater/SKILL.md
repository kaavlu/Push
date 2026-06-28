---

title: Documentation Auto-Updater
description: Selectively updates project context files after meaningful Git commits, keeping agents.md and CLAUDE.md compact and useful.
gating-criteria: There is a new Git commit or a manual request to sync durable project context.
-----------------------------------------------------------------------------------------------

# Documentation Auto-Updater Skill

## Goal

Keep project context files accurate without creating context bloat.

When activated, inspect the latest Git commit and update `agents.md` and/or `CLAUDE.md` only when the commit introduces durable information that future coding agents need in order to work correctly.

Prefer no update over a low-value update.

## Files to Maintain

At the repository root:

* `agents.md`
* `CLAUDE.md`

If one file does not exist, do not create it unless the latest commit introduces durable context that clearly belongs there.

## Workflow

1. Inspect the latest commit:

   ```bash
   git show --stat --name-status --find-renames HEAD
   ```

2. Inspect the actual diff only for relevant files:

   ```bash
   git show --find-renames -- <relevant-file-paths>
   ```

3. Open existing context files:

   ```bash
   cat agents.md 2>/dev/null
   cat CLAUDE.md 2>/dev/null
   ```

4. Decide whether the commit contains durable context worth documenting.

5. If there is nothing durable to add, make no changes and do not create a commit.

6. If updates are needed, edit the relevant context file(s), then commit with:

   ```bash
   git add agents.md CLAUDE.md
   git commit -m "docs: auto-update agents.md and CLAUDE.md [skip ci]"
   ```

## What Counts as Durable Context

Only document information that will matter across future development sessions.

Add or update context for:

* Architecture decisions.
* Persistent project structure changes.
* New required setup steps.
* New build, test, lint, or run commands.
* Important framework, dependency, or platform choices.
* Reusable UI/design rules.
* Security, privacy, permissions, or data handling constraints.
* Repeated gotchas that could cause future bugs.
* Agent workflow rules that affect how future changes should be made.

Do not document:

* One-off implementation details.
* Temporary experiments.
* Simple styling tweaks.
* Small copy changes.
* Routine refactors with no future implication.
* Generated files.
* `node_modules/`.
* Lockfile-only changes unless they reflect an intentional dependency or tooling change.
* Build artifacts, caches, screenshots, or IDE metadata.
* Large file lists.
* Raw diffs.
* Commit summaries that merely restate what changed.

## Bloat Control Rules

Before adding anything, ask:

1. Will this still matter 2 weeks from now?
2. Would a future coding agent make a worse decision without this context?
3. Is this already captured somewhere in `agents.md` or `CLAUDE.md`?
4. Can this be expressed as a rule, constraint, or stable project fact?

If the answer is not clearly yes, do not add it.

## Editing Rules

* Prefer updating or tightening existing bullets over adding new sections.
* Avoid duplicate instructions across `agents.md` and `CLAUDE.md`.
* Keep additions short: usually 1–3 bullets total.
* Use compact, directive language.
* Do not include timestamps unless they are part of a durable decision.
* Do not include commit hashes unless specifically useful.
* Do not create changelogs.
* Do not summarize every commit.
* Preserve existing formatting and section organization.
* If a section is getting long, consolidate related bullets instead of appending.

## Suggested File Responsibilities

Use `agents.md` for:

* Repo structure.
* Build/test commands.
* Development workflow.
* Agent-specific coding rules.
* Common pitfalls.

Use `CLAUDE.md` for:

* Claude/Cursor-specific behavior.
* Project-specific AI instructions.
* How agents should plan, edit, test, and verify work.

If the same rule applies to both files, place it in the more relevant file only.

## No-Op Behavior

If the latest commit does not contain durable context, stop after inspection.

Do not edit files.
Do not create an empty commit.
Do not add filler notes.
Do not force an update just because the hook ran.

## Safety

The auto-generated documentation commit must include `[skip ci]` in the commit message to prevent recursive hook execution.
