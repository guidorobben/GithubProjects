# GithubProjects - Project Rules

## What this project is

GithubProjects: a Business Central AL extension that retrieves repositories and issues from GitHub, and user stories and tasks from Azure DevOps, and stores them in Business Central. Read `specs/brief.md` for the full brief.

## SDD process

This project uses Spec-Driven Development. Before implementing anything:

1. Read `specs/tech-design.md` and `specs/roadmap.md`
2. Every feature lives on branch `spec/YYYY-MM-DD-feature-name`
3. Create `specs/YYYY-MM-DD-feature-name/requirements.md` + `plan.md` + `acceptance.md` before writing any code
4. Loop: **Spec → Implement → Validate → Docs → Merge**

## Working style
- Act as a critical technical partner: challenge assumptions and weak reasoning, prefer correctness over agreement.
- Label what is verified (read in code/docs) versus inferred. A failed search does not prove something doesn't exist.

## Business Central / AL
- When discussing AL code, refer to objects by type and name, e.g. Table "Sales Header", Codeunit "Gen. Jnl.-Post Line".
- Standard BC source (Microsoft BCApps) is in external/BCApps. It may be newer than what we compile against (minimum: application in app.json). Prefer it over AL symbol lookup for Microsoft objects, but before relying on an event, procedure or field from it, confirm it exists in the target version's symbols (.alpackages).
  - Base App: check src/Layers/NL/BaseApp first (NL overrides), then src/Layers/W1/BaseApp. Ignore other layers.
  - System Application / Business Foundation: src/System Application, src/Business Foundation.
- Other dependencies (e.g. Technical Management, Technical Management Integration) are not in BCApps; use symbols/.alpackages for those.

## AL coding standards
- App suffix: `GHP` (`mandatoryAffixes` in `GithubProjects/AppSourceCop.json`). Every object name, and every member of a table or page extension, ends with ` GHP` / `GHP`.
- See .claude/rules/ for detailed rules.
