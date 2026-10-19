---
name: create-feature-spec
description: Start the next feature in the Spec-Driven Development loop. Reads the project rules
  (CLAUDE.md, .claude/rules), the brief, the roadmap and the tech design, picks the next planned
  feature from the roadmap, creates the branch spec/YYYY-MM-DD-feature-name, and writes
  specs/YYYY-MM-DD-feature-name/requirements.md, plan.md and acceptance.md. Use at the start of a
  feature, before any code is written.
disable-model-invocation: true
---

# Create the spec for the next feature

Implements the **Spec** step of the SDD loop (Spec → Implement → Validate → Docs → Merge) in
`CLAUDE.md`. The output is three documents that define what is built, how, and when it is done.
No AL code is written in this skill.

This skill assumes the session runs from the workspace (`al.code-workspace`). Locate the repo root
through `specs/brief.md`. All paths below are relative to the repo root.

Argument (optional): the roadmap feature name, or its issue number. Without it, use the next
planned feature (Step 2).

## Step 1 - Read the constitution

The project has no single "constitution" file. These together are the constitution, read all of
them before anything else:

- `CLAUDE.md`: the SDD process, working style, Business Central conventions (BCApps layers,
  verifying against the target symbols).
- `.claude/rules/*.md`: AL coding standards and the Bluace rules (compile, folders, helper
  codeunits, no code on pages, RunTrigger, table extension triggers, testing, dev environment).
  The plan must follow them; quote the rule when a plan decision depends on it.
- `specs/brief.md`: the customer's wording and numbered requirements.
- `specs/tech-design.md`: the agreed design per feature (*What standard BC provides*, *Gaps*,
  *Implementation decision*) and the **Key design decisions**.
- `specs/roadmap.md`: features, status, implementation summary and "done when".
- Earlier feature folders `specs/YYYY-MM-DD-*/`: reuse their structure and conventions.
- The target app: `app.json` (ID range, runtime, application version, dependencies,
  `internalsVisibleTo`), `.vscode/settings.json` (analyzers, ruleset, mandatory suffix),
  `AppSourceCop.json`, existing objects and folder layout. For a new test app, also the test app's
  `app.json`.

## Step 2 - Pick the feature

1. In `specs/roadmap.md`, take the first row (top to bottom) with status `planned`, unless the
   argument names another one. Skip rows whose dependencies are not `done` yet (e.g. a feature
   that builds on another feature's public method), and say why.
2. Find its section in `specs/tech-design.md` and its requirements in `specs/brief.md`.
   - If the tech design has **no section** for the feature, stop: the design must be agreed first.
     Tell the user what is missing.
   - If brief, tech design and roadmap contradict each other, list the contradictions and ask
     before writing anything.
3. Tell the user which feature you picked, the app(s) it touches, and the brief requirements it
   covers. Wait for confirmation before Step 3.

## Step 3 - Create the branch

- Name: `spec/YYYY-MM-DD-feature-name`, with today's date and a short kebab-case name derived
  from the roadmap feature (e.g. `spec/2026-10-05-mollie-payment-link-management`).
- Branch from the up-to-date default branch (`main`). Check `git status` first: if there are
  uncommitted changes, stop and ask.
- Use the same `YYYY-MM-DD-feature-name` for the spec folder.
- Do not push and do not commit unless the user asks.

## Step 4 - Verify before you specify

Every fact the spec relies on must be checked, and labelled verified or inferred (CLAUDE.md):

- **Standard objects, fields, procedures and events** in `external/BCApps` (Base App: NL layer
  first, then W1; System Application; Business Foundation), and then **confirmed in the target
  version's symbols** (`.alpackages`), because BCApps may be newer than the version the app
  compiles against.
- **Other dependencies** (e.g. Technical Management, Base Functionality) through their symbols in
  `.alpackages` only.
- **External APIs** through their official documentation; note the URL.
- **Object IDs**: free IDs inside the app's `idRanges` (check existing objects, or use the AL MCP
  `al_getnextobjectid`).

General checks, learned from earlier features:
- **Documentation is not proof.** Microsoft Learn and other docs can be outdated or wrong for the
  target version. When the design depends on platform behaviour, verify it in source or symbols,
  and plan a test that proves it.
- **Know which app does the work.** Platform settings and permissions can apply per extension
  (e.g. outbound HTTP in a sandbox). When the feature calls through another app's helper, check
  whose settings and permissions apply, and plan a manual check for what tests cannot show.
- **Check what helpers really send or do.** Standard wrappers can add defaults that an external
  system rejects (headers, content, formats). Read the helper's source for every call the
  feature makes, and compare it with the external system's requirements.
- **Enforce every rule where it is decided.** A UI filter or a hidden action is a convenience. The
  same rule must also be checked in the procedure that every caller uses, so other callers (a
  report, an API, a later feature) cannot bypass it.

## Step 5 - Write requirements.md

```markdown
# Requirements — <Feature name>

Roadmap: [<Feature name>](../roadmap.md) ([#<issue>](<issue URL>)).
Tech design: [<Feature name>](../tech-design.md#<anchor>).
Brief: [<brief section>](../brief.md), requirements <n–m>.
App: <app>. Branch: `spec/YYYY-MM-DD-feature-name`.

## Goal

<One sentence, matching the roadmap's "Delivers".>

## Definitions

- **<Term>**: <precise definition used in the requirements, e.g. "Active link", "Open invoice">.

## Functional requirements

### R1 — <Area>

- R1.1 <One testable statement per line: who can do what, and what the system does.>
- R1.2 ...

### R2 — ...

## Non-functional requirements

- <Security (e.g. secrets stay SecretText), translations (which languages), performance,
  separation of concerns needed by a later feature, "no change to standard objects", automated
  tests without external communication.>

## Explicitly NOT included

- <Everything a reader might expect but is out of scope: later roadmap features, edge cases,
  accepted risks from the tech design, decisions to leave something out (with date).>
```

Rules:
- Number every requirement (R<n>.<m>); acceptance and tests refer to these numbers.
- One behaviour per line, testable, in the user's terms plus exact object/field names.
- Every brief requirement in scope maps to at least one R; every accepted risk and every
  out-of-scope item from the tech design appears under *Explicitly NOT included*.
- Record decisions with their date, e.g. "(decided 2026-10-05)".

## Step 6 - Write plan.md

```markdown
# Plan — <Feature name>

Implements [requirements.md](requirements.md) as decided in [tech-design.md](../tech-design.md#<anchor>).
App: <app> (ID range <from–to>, runtime <x>, application <y>). Standard objects are not modified.

## Naming and structure
- <Suffix/affix rule from AppSourceCop.json, caption rule, Access = Internal, folder layout per
  bluace-folder-structure.md (tree), deviations from the tech design and that they are updated in
  the Docs step.>

## Objects

| Type | ID | Name | Caption | File | Folder |
| --- | --- | --- | --- | --- | --- |

## <One section per object or object pair>
<Fields (table with No., Name, Type, properties, triggers), keys, procedures with signatures,
which requirement each implements, labels, permissions, commits and locks with the reason.
Table procedures only call the helper codeunit (bluace-helper-codeunits.md); pages only call
table procedures (bluace-page-code.md); field and record reactions use table extension triggers
(bluace-table-triggers.md); every write states RunTrigger (bluace-run-trigger.md).>

## Test app (automated tests)
<Test app setup and dependencies (bluace-testing.md rule 6), one test codeunit per acceptance
section, a separate codeunit for TestPage scenarios (the AL MCP runner cannot run them), a test
library, mocks for external calls injected through an [InternalEvent] plus backstops (unresolvable
`.invalid` host, dummy secrets), permission tests with Permissions Mock.>

## Permission sets
<Every set, its objects and permissions, who gets it, and why (e.g. a separate admin set when a
setting can redirect secrets).>
```

Rules:
- Every R from requirements.md is implemented by at least one plan section; name it.
- Mark each fact verified (with `file:line` or symbol) or inferred / "to be confirmed at compile
  time".
- State every deviation from the tech design explicitly, so the Docs step can update it.

## Step 7 - Write acceptance.md

```markdown
# Acceptance — <Feature name>

Defines done for [requirements.md](requirements.md).

- **Sections A–<X> are automated tests** in the test app (see [plan.md](plan.md#<anchor>)).
  <Where they run, and how external communication is excluded.>
- **Section M is the short manual list.** It covers what a mock cannot prove.

## Conventions for the automated tests
- <Fixture names, "No request", what the mock checks after each test, environment assumptions.>
- **Test data**: <named records, e.g. INV-A…INV-G, with exactly the properties scenarios rely on.>
- **Permissions**: <which permission set each section runs with.>

## A. <Area> (R<n>)

| # | Given | When | Then |
| --- | --- | --- | --- |
| A1 | ... | ... | ... |

## M. Manual checks (<where>)

<When and where they run.>

| # | Check | Pass when |
| --- | --- | --- |

## G. Quality gates

- G1 Compiles without errors and without new warnings under the workspace analyzers and the
  Bluace ruleset (bluace-compile.md).
- G2 All automated tests pass in the AL-Go pipeline (no external communication).
- G3 All user-facing texts are Labels; every supported language has a complete translation file,
  in the app and the test app (bluace-testing.md rule 7).
- G4 <Feature-specific security or data gate.>
- G5 No standard object and no other app is modified (unless the spec says so).
- G6 Section M passed, results recorded in the PR.
- G7 After merge: `specs/tech-design.md`, `specs/roadmap.md` (status `done`), `docs/user-guide.md`
  and `CHANGELOG.md` are updated, per the SDD loop.

## Not covered here
<Checks that belong to another feature's spec.>
```

Rules:
- One section per requirement area, IDs `<letter><number>` (sub-cases `B13a`), each referring to
  its R numbers. Test procedures will be named after these IDs (bluace-testing.md rule 5).
- Every R has at least one scenario; every refusal rule has a scenario that proves "no request /
  no change".
- Given/When/Then are concrete: exact data, exact expected values or messages, the expected
  sequence of external requests.
- Put in section M only what cannot be automated: real external API behaviour, environment
  and extension settings, environment copy, concurrency.
  UI filters and page actions are automated as TestPage scenarios, not manual.

## Step 8 - Self-check and hand over

1. Traceability: brief requirement → R → plan section → acceptance ID. List any gap.
2. Consistency: names, IDs, captions and numbers are the same in all three files.
3. Every open question or unverified fact is listed at the end of the hand-over, not hidden in
   the documents.
4. In `specs/roadmap.md`, set the feature's status to `in-progress`.
5. Line endings: the repo uses CRLF (`core.autocrlf` true). Write with the Write/Edit tools or
   PowerShell with absolute paths; do not use Git Bash `sed -i` (it converts CRLF to LF). Normalise
   new files to CRLF without BOM.
6. Report to the user: branch name, the three files with a one-line summary each, the
   requirement count and acceptance count, deviations from the tech design, and the open questions.
   Do not commit unless the user asks. The next step is **Implement**.
