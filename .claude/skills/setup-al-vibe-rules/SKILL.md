---
name: setup-al-vibe-rules
description: Bootstrap an AL project with the official Microsoft AL vibe coding rules
  from the alguidelines GitHub repo. Downloads all rule files to .claude/rules/, adds
  .claude/ to the workspace file, and updates CLAUDE.md with the location of these rules.
  Use when starting a new AL project, onboarding a new developer, or refreshing stale rule files.
disable-model-invocation: true
---

# Setup AL Vibe Coding Rules

Fetches the official Microsoft AL coding rules from GitHub and wires them into the
VSCode project so every future agent session follows them automatically.

This skill assumes the session runs from the workspace (al.code-workspace), so the
current working directory is the repo root. All paths below are relative to it.

## Step 1 - Discover files in the GitHub folder

Call the GitHub Contents API to get the current file list (never hard-code filenames):

GET https://api.github.com/repos/microsoft/alguidelines/contents/content/docs/agentic-coding/vibe-coding-rules

Parse the JSON response and collect every entry where "type": "file" and the name
matches al-*.md. Skip README.md, _index.md and any other non-rule files.
Extract the name and download_url of each file.

## Step 2 - Download each file directly into .claude/rules/

Empty the .claude/rules/ directory first (or create it if missing), so rules that were
removed or renamed upstream do not linger. Then download every file from its
download_url into .claude/rules/<filename>.
Do NOT use WebFetch and then Write - download straight to disk.

On Windows (PowerShell), run all downloads in one shell call:

New-Item -ItemType Directory -Force -Path ".claude/rules" | Out-Null
Get-ChildItem ".claude/rules" -File | Remove-Item -Force
Invoke-WebRequest -Uri "<download_url>" -OutFile ".claude/rules/<filename>"

Chain multiple downloads with ; so every file is saved in a single round-trip.

## Step 3 - Add .claude/ to the workspace file

Read al.code-workspace, add { "path": ".claude" } to the folders array if not already
present, and write it back. Keep the existing formatting and entries intact.

## Step 4 - Add the AL coding standards section to CLAUDE.md

Append the following section to CLAUDE.md. Skip this step if CLAUDE.md already contains
a `# AL coding standards` heading.

```markdown
# AL coding standards
- See .claude/rules/ for detailed rules.
```

## Verification

After completing all steps, confirm:
- .claude/rules/ contains exactly the al-*.md files from the GitHub folder
- al.code-workspace has { "path": ".claude" } in folders
- CLAUDE.md contains the `# AL coding standards` section exactly once

## Notes
- Always fetch from GitHub - never generate or paraphrase rule content.
- CLAUDE.md should be kept short; detailed rules live in .claude/rules/.
