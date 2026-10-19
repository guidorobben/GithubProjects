---
name: finalise-feature
description: Close a feature in the Spec-Driven Development loop after it is built, validated and
  documented. Appends a CHANGELOG.md entry, syncs specs/tech-design.md with what was actually
  built, marks the feature done in specs/roadmap.md, replans the remaining roadmap features, and
  prepares the merge of the spec branch into main through a pull request. Use as the Merge step,
  after /generate-docs.
disable-model-invocation: true
---

# Finalise a feature

Implements the **Merge** step of the SDD loop (Spec → Implement → Validate → Docs → Merge) in
`CLAUDE.md`. It makes sure the specs describe what was built, records the change, and gets the
branch merged. It writes no AL code.

This skill assumes the session runs from the workspace (`al.code-workspace`). Locate the repo root
through `specs/brief.md`. All paths below are relative to the repo root.

Argument (optional): the feature folder name, e.g. `2026-10-05-mollie-payment-link-management`.
Without it, derive it from the current branch `spec/YYYY-MM-DD-feature-name`.

## Step 1 - Check that the feature is ready

Read `specs/<feature>/requirements.md`, `plan.md`, `acceptance.md`, the feature's sections in
`specs/tech-design.md` and `specs/roadmap.md`, and `docs/user-guide.md`.

Check, and report each item as done / not done / unknown:
- The branch is `spec/<feature>` and `git status` is clean, or only has finalisation changes.
- Quality gates in `acceptance.md` (section G): compile without warnings (bluace-compile.md),
  automated tests pass, translations complete, manual checks (section M) passed. Ask the user for
  the results of manual checks and pipeline runs you cannot see; never assume they passed.
- `docs/user-guide.md` covers the feature (otherwise run `/generate-docs` first).

If something is not done, stop and tell the user what is missing. Continue only when the user
says so.

## Step 2 - CHANGELOG.md

- If `CHANGELOG.md` does not exist at the repo root, create it with the heading `# Changelog`.
- Append (at the end) one entry for the feature:

```markdown
YYYY-MM-DD — <Feature name as in the roadmap>
<One sentence describing what was built, in user terms, matching the roadmap's "Delivers".>
```

- Use today's date. Separate entries with a blank line. Do not rewrite earlier entries.

## Step 3 - Sync specs/tech-design.md with what was built

The tech design is the long-lived record of decisions. After implementation it must describe
the actual system, not the original intention.

1. Collect the differences between the feature's tech-design section and the implementation:
   - deviations already flagged in `plan.md` (search for "deviates", "updated in the Docs step",
     "changed", "decided YYYY-MM-DD");
   - decisions taken during implementation and validation (recent commits on the branch, changes
     to requirements/plan/acceptance since the spec was first committed: `git log` and
     `git diff <first spec commit>..HEAD -- specs/<feature>`);
   - the code itself. Check at least: object and field names, where values are stored (constants
     vs setup fields), how secrets are stored, which triggers/events are used, permission sets,
     every eligibility or validation rule, commits and locks, external calls (helpers, handlers,
     headers), pages and actions added, behaviour on delete, copy and environment type.
2. Verify every difference in the code (`file:line`) before writing it down.
3. Update the relevant subsection where the decision is described, instead of adding a separate
   "changes" list. Mark each change inline with *Changed during implementation:* or *Added during
   implementation:*, and keep the reason (and the date when there was a decision).
4. Update **Key design decisions** at the end of the file so it matches the updated sections.
5. Do not touch the sections of other features in this step (that is Step 5).

## Step 4 - specs/roadmap.md

- Set the feature's **Status** to `done`.
- If the **Implementation** or **Done when** text no longer matches what was built, correct it in
  the same style (short, factual).

## Step 5 - Replan the remaining features

Check what this feature changed for the features that are still `planned` or `in-progress`:

1. For each remaining roadmap row, read its tech-design section and its brief requirements.
2. Look for impact from this feature:
   - names or interfaces the next feature relies on (object names, suffixes, public procedures,
     events, permission sets);
   - decisions or limitations found during implementation (platform behaviour, external API
     behaviour, accepted risks) that also apply to the next feature;
   - work that was moved in or out of this feature's scope ("Explicitly NOT included", "Not
     covered here");
   - order and dependencies: is the next feature now unblocked, or does it need something first?
3. Propose the changes to the user as a short list: roadmap rows (order, status, implementation
   text, dependencies) and tech-design sections of later features.
4. Apply only the changes the user approves. Do not change the scope or the order of features on
   your own.

## Step 6 - Commit, pull request and merge

All of these are outward-facing or hard to undo: ask the user before each one.

1. **Commit** the finalisation changes on the spec branch with a message like
   `Finalise <feature name>: changelog, tech design, roadmap`. End the message with the
   attribution lines from the system reminder, if one is present.
2. **Push** the branch (`git push -u origin <branch>`).
3. **Pull request** into `main` with `gh pr create`:
   - title: the feature name as in the roadmap;
   - body: what was built (from the changelog sentence and the requirements' goal), links to the
     spec folder and the user guide section, the quality gate results from Step 1 including the
     manual checks (acceptance G6 asks to record them in the PR), deviations from the tech design,
     and the follow-ups from Step 5. End with the attribution line from the system reminder, if
     present.
   - The AL-Go CI/CD workflow runs on the PR; report its status (`gh pr checks`).
4. **Merge** only after the user confirms and the checks pass. The repo squash-merges PRs into
   `main` (commit titles end with `(#<PR>)`): `gh pr merge <n> --squash`. Ask before deleting the
   branch.
5. Version increments and AL-Go system file updates run as separate workflows in this repo; do not
   do them here unless the user asks.

## Step 7 - File hygiene

- Files in this repo use CRLF; `core.autocrlf` is true.
- Edit with the Write/Edit tools or PowerShell with **absolute paths**. Do not use Git Bash
  `sed -i`: it converts CRLF to LF, and appending `\r` afterwards leaves a stray carriage return on
  a last line without newline, after which Git treats the file as binary.
- Normalise new or edited Markdown files to CRLF without BOM, for example:

```powershell
$f = 'C:\Repositories\pteaquacell\CHANGELOG.md'
$t = [IO.File]::ReadAllText($f)
[IO.File]::WriteAllText($f, ($t -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding($false)))
```

## Step 8 - Report

Tell the user:
- the changelog entry;
- the tech-design changes as a table (area / design said / actually built), each verified in code;
- the roadmap status change;
- the replanning proposals and which ones were applied;
- the commit, PR and merge state, with links;
- anything left open (gates not confirmed, questions for the next feature).
