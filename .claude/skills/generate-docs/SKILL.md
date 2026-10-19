---
name: generate-docs
description: Write or update the end-user guide (docs/user-guide.md) for a feature that has just been
  implemented, verify every statement against the code, and have it reviewed by the BC Code
  Intelligence personas Taylor Docs and Uma UX. Use in the Docs step of the SDD loop
  (Spec → Implement → Validate → Docs → Merge), after the feature is built and its tests pass.
disable-model-invocation: true
---

# Generate user documentation for a feature

Produces or extends `docs/user-guide.md`, a living guide for AquaCell users and administrators
that grows with every feature. The reader is a Business Central user, not a developer.

This skill assumes the session runs from the workspace (`al.code-workspace`). Locate the repo root
through `specs/brief.md`. All paths below are relative to the repo root.

Argument (optional): the feature folder name, e.g. `2026-10-05-mollie-payment-link-management`.
Without it, derive it from the current branch `spec/YYYY-MM-DD-feature-name`.

## Step 1 - Read the inputs

1. `specs/brief.md`, `specs/roadmap.md`, `specs/tech-design.md` (the feature's section).
2. The feature spec: `specs/<feature>/requirements.md`, `plan.md`, `acceptance.md`.
3. The existing `docs/user-guide.md`, if any.

Note which features in the roadmap are `done`, which app each belongs to, and what is explicitly
*not* built yet (out of scope, later features). Never document something that is not built.

## Step 2 - Workspace

Add `docs` to the `folders` of `al.code-workspace` (after `specs`) if it is not there yet.

## Step 3 - Collect the facts from the code, not from the spec

The spec says what was intended; the guide must describe what was built. For every statement you
plan to write, find the code that makes it true. Collect at least:

- **Captions** exactly as the user sees them: `Caption` of pages, fields, actions and action groups,
  and `ToolTip`s. Check the `Translations/*.xlf` files for the Dutch captions.
- **Standard BC UI** you refer to (pages, actions, fields of Microsoft objects): verify in
  `external/BCApps` (NL layer first, then W1; System Application for things like Extension
  Management and Users). Microsoft Learn is often out of date for UI captions. Verified examples
  for BC 29:
  - Extension Management has no *Configure*: choose **View**, which opens **Extension Settings**
    with **Allow HttpClient Requests**.
  - Permission sets are added in **User Permission Sets** on the user card.
  - The promoted group with caption *Invoice* on Posted Sales Invoice(s) is `Category_Category4`.
- **Behaviour** in the helper codeunits, especially:
  - which records an action works on (a selection through `SetSelectionFilter`, or only the current
    line through `Rec`);
  - what happens before the main action (e.g. a refresh from the external service first);
  - every check that refuses the action, **in the order the code checks them**, and any check that
    happens before a page opens;
  - `Commit()` calls: they decide what is kept when a later step fails;
  - what is shown on success (often no message at all: say where the result appears instead);
  - permissions: which permission set gives what, and what still needs standard permissions;
  - environment-specific behaviour (sandbox/production, environment copy, on-premises);
  - fallbacks (blank fields, missing translations, default values filled in automatically);
  - deletion rules and what is deleted along with a record.
- **Setup prerequisites** outside the app, e.g. *Allow HttpClient Requests* in a sandbox when the
  feature calls an external service.

Keep a short list of statement → evidence (`file:line`) while you write. Label anything you could
not verify in code as inferred, and leave it out of the guide unless the user confirms it.

## Step 4 - Write or update docs/user-guide.md

### Document structure

When creating the file:

```markdown
# AquaCell Business Central – User Guide

## About this extension

<2-3 sentences, plain language: which AquaCell extensions this guide covers and which problems
they solve. Mention every feature that is done, also those without a section yet.>

## Table of contents

- [<Feature title>](#<anchor>)
```

When updating: add the new feature to the table of contents and, if needed, to the intro. Do not
rewrite other features' sections unless they are now wrong.

### Feature section

```markdown
## <Feature title>

### What this feature does

<One paragraph: what the user can do, the main rules (limits, amounts, what is sent to whom),
and what it does not do when that is likely to be assumed.>

### Setup

<Who can do this: the app's admin permission set, plus "normal administrator permissions" for
standard pages.>

1. Search for **<Page>** and open it.
2. <One action per step, with the exact caption and what the user sees afterwards.>
...

Good to know:
- <Setup facts the user needs later: how to undo, what happens on environment copy, read-only
  behaviour for other users.>

### How to use

**<Task 1, phrased as the user's goal>**

1. <Start point: "Search for **X** and open it." or "On the **X** page, ...">
2. <One action per step. End with the outcome: where the result appears, "No message is shown".>

<Refusal rules for the task as a bullet list, in the order the code checks them.>

**<Task 2>** ...

Good to know:
- <Cross-cutting behaviour: status not updated automatically, what is not posted, environment
  separation, deletion, error behaviour per action.>
```

Do not add a "Related features" section or other placeholders: add a section only when it has
content.

### Writing rules

- **Audience:** Business Central users and administrators. No AL or developer terms: say
  "closed" or "fully paid or applied" instead of "customer ledger entry is closed", "line" instead
  of "record", "check box" instead of "Boolean", "list of posted sales invoices" instead of
  "lookup", never FlowField, codeunit, table extension, Rec, Commit, isolated storage.
- **Captions** in bold, exactly as in the client (English). Use **Bal. Account No.**, not
  "balancing account".
- **Dutch captions** only where they matter for the process (e.g. the text a customer sees:
  "Factuur" vs "Invoice"). Do not add a Dutch caption list.
- **Steps:** numbered, one action each, a clear start point, the outcome stated.
- **No absolute claims** the code does not guarantee ("never", "nothing is changed"). State the
  exact behaviour, per action if it differs.
- Say what the user cannot see: no confirmation message, status only updated on demand, refunds
  ignored, payments not posted.

## Step 5 - Review with the BC Code Intelligence personas

Run the review in a **subagent** (general-purpose) so the review is independent of the writer.
Instruct it to:

1. Load the `bc-knowledge` tools with ToolSearch. Call `set_workspace_info` first
   (`workspace_root` = repo root with forward slashes, `available_mcps` = the connected servers);
   without it the server answers "Server Not Yet Initialized".
2. Call `ask_bc_expert` with `preferred_specialist: "taylor-docs"` and with `"uma-ux"`, passing the
   guide as context. These calls return the persona's instructions and review lens, not a finished
   review: the subagent must apply the lens itself.
3. Check: accuracy against the code and specs, nothing invented, steps clear and actionable, plain
   language without AL jargon, captions as in the client. Point it to the app source, the
   translation files, the feature spec, `external/BCApps` for standard pages, and to what is
   deliberately out of scope.
4. Report only, no edits: grouped as **Inaccurate / invented** (must fix), **Missing**,
   **Clarity & language**, each with the guide text and line, evidence (`file:line`), proposed
   wording, persona, and verified vs inferred.

If `bc-knowledge` is not connected, tell the user before running the review, and let the subagent
review from the two roles while stating that the personas did not load.

## Step 6 - Verify the findings, then apply them

- Before applying a finding, check its evidence yourself for anything that changes a user step or
  a rule (captions of standard pages, `Commit()` behaviour, fallbacks). Reviewers can be wrong.
- Apply the confirmed findings. Ask the user only for real choices (e.g. whether to add a section
  for an older feature).
- If the fixes were substantial, run the review once more (Step 5) and repeat until there are no
  must-fix findings.

Mistakes that earlier reviews caught, check for them explicitly:
- "If the service cannot be reached, nothing is changed": false when the code commits a refresh
  before the failing call. Describe it per action.
- "In the customer's language": the language comes from a field on the document, with a fallback
  (the user's language) when it is blank, and only the translated languages differ.
- "The invoice total": state exactly which amount (including VAT, full amount even when partly
  paid).
- "The token is stored encrypted": only when encryption is enabled; say "stored securely".
- "Clear the field to remove it": a masked input field that is emptied after validation cannot be
  cleared; only the explicit action works.
- An action on a list that works on the current line only, while the user may select several.
- An environment-copy subscriber runs on every copy, not only to a sandbox.
- Admin permission set described as sufficient while steps need standard permissions too.
- UI routes taken from Microsoft Learn (e.g. *Configure* in Extension Management) that no longer
  exist in the target BC version.

## Step 7 - File hygiene

- Files in this repo use CRLF; `core.autocrlf` is true.
- Edit with the Edit/Write tools or PowerShell with **absolute paths** (`[IO.File]` resolves
  relative paths against the process folder, not the PowerShell location).
- Do **not** use Git Bash `sed -i` on these files: it converts CRLF to LF, and appending `\r` to
  restore it leaves a stray carriage return on a last line without newline, after which Git treats
  the file as binary.
- After writing, normalise new or edited Markdown files to CRLF without BOM, for example:

```powershell
$f = 'C:\Repositories\pteaquacell\docs\user-guide.md'
$t = [IO.File]::ReadAllText($f)
[IO.File]::WriteAllText($f, ($t -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding($false)))
```

## Step 8 - Report

Start the hand-over with one line naming the audience (e.g. "Written for: AquaCell users and
administrators who work in Business Central."). Summarise what was added, which review findings
were applied, anything left open, and which statements are inferred. Do not commit; leave that to
the user.
