# Roadmap

Ordered queue of features. Each feature builds only on the ones above it. Source: [brief.md](brief.md), [tech-design.md](tech-design.md).

Every feature follows the SDD loop (Spec → Implement → Validate → Docs → Merge) and brings its own permissions, tests and docs.

---

## 1. Base URLs and tokens

- **Delivers:** the user can register GitHub and Azure DevOps base URLs, each with its own secret token.
- **Status:** done ([spec](2026-10-20-base-urls-and-tokens/requirements.md))
- **How:** one record per base URL with a source type; the token goes to company-scoped Isolated Storage through the standard password dialog after a write-permission check, and is wiped after an environment copy — [tech design §1](tech-design.md#1-settings-multiple-base-urls), decisions 1, 2, 16, 17.
- **Done when:** a user with write permission can set and clear a token, nobody can read it back, a duplicate URL is refused, and a copied environment has no tokens.

## 2. GitHub repositories

- **Delivers:** the user maintains GitHub owners and retrieves their repositories, including the token user's private ones, on demand.
- **Status:** done ([spec](2026-10-20-github-repositories/requirements.md))
- **How:** the app's own HTTP handler and a GitHub client that follows `link` paging and recognises rate limits; each owner is fetched completely, then upserted and pruned in its own isolated unit of work; deleting a base URL now cascades to its owners and repositories, and its Source Type is locked once owners exist (both moved here from feature 1) — [tech design §1](tech-design.md#1-settings-multiple-base-urls), [§2](tech-design.md#2-owners-github-only), [§7](tech-design.md#7-data-retrieval-with-the-rest-client), [§8](tech-design.md#8-repeated-retrieval-upsert-and-removal), decisions 4, 5, 9, 10, 18, 19.
- **Done when:** repeated updates of user and organization owners give no duplicates, remove repositories no longer returned, leave data untouched after a failed request, deleting a base URL removes its owners and repositories, the Source Type of a base URL with owners cannot change, and HTTP works in a sandbox with requests allowed on this app only.

## 3. GitHub issues

- **Delivers:** the user sees the open and closed issues of the repositories they choose to include.
- **Status:** planned
- **How:** issues per included repository, skipping pull requests and repositories with issues turned off, stored in the shared issue list; the user's include/ignore choice survives every update and stored issues can be deleted on request; Issue Sync and Issues Enabled already exist on the repository table (feature 2), so this feature adds the repository helper (deleting a repository deletes its issues), Delete Issues and Update Repositories and Issues, and refuses a `github.com` base URL with a hint to `https://api.github.com` — [tech design §3](tech-design.md#3-repositories-and-projects), [§4](tech-design.md#4-github-issues), [§6](tech-design.md#6-the-shared-issue-table), decisions 6, 13, 14, 20.
- **Done when:** no pull request is ever stored, ignored repositories are skipped but keep their issues, Delete Issues removes them after confirmation, deleting a repository deletes its issues, and a `github.com` base URL is refused with the API address as hint.

## 4. Azure DevOps projects

- **Delivers:** the user retrieves all Azure DevOps projects the token can access, on demand from the base URL list.
- **Status:** planned
- **How:** an Azure DevOps client with basic authentication on the same HTTP handler, paging projects until an empty page, reusing the upsert-and-prune unit of work from feature 2 and its test mock (the mock hook moves from the GitHub client to a shared handler factory); a deleted base URL also deletes its projects; the Source Type of a base URL is locked once projects exist (moved here from feature 1) — [tech design §1](tech-design.md#1-settings-multiple-base-urls), [§3](tech-design.md#3-repositories-and-projects), [§7](tech-design.md#7-data-retrieval-with-the-rest-client), decisions 3, 20.
- **Done when:** projects appear next to GitHub repositories, a base URL without a token fails with a clear message, removed projects disappear on the next update, and the Source Type of a base URL with projects cannot change.

## 5. Azure DevOps user stories and tasks

- **Delivers:** the user sees each project's user stories with their tasks as a collapsible tree, open or closed.
- **Status:** planned
- **How:** a WIQL query for ids, batches of up to 200 work items, state mapped through its category, and the tree computed after each project's upsert — [tech design §5](tech-design.md#5-azure-devops-user-stories-and-tasks), [§6](tech-design.md#6-the-shared-issue-table), decisions 7, 8, 20.
- **Done when:** tasks sit under their stored user story (orphans at top level), custom states map correctly, and a work item that is deleted or changes type disappears on the next update.

## 6. Scheduled update

- **Delivers:** the user schedules one job that keeps all GitHub and Azure DevOps data up to date, and manual and scheduled runs never collide.
- **Status:** planned
- **How:** a job queue entry created On Hold from the settings page, running the same update logic as the manual actions (the owner update loop already shows no message without a GUI, and its error stays under the 2048 characters of the job queue error), ending with one error that lists all failures, guarded by a session-based lock — [tech design §7](tech-design.md#7-data-retrieval-with-the-rest-client), decisions 9, 11, 12.
- **Done when:** the job updates everything, one failing owner or project does not stop the rest and shows up in the job queue log, and a second run during an active one stops with a message naming the running session.
