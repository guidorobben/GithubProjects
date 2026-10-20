# Requirements — GitHub repositories

Roadmap: [2. GitHub repositories](../roadmap.md#2-github-repositories).
Tech design: [§2 Owners](../tech-design.md#2-owners-github-only), [§3 Repositories and projects](../tech-design.md#3-repositories-and-projects) (GitHub part), [§7 Data retrieval](../tech-design.md#7-data-retrieval-with-the-rest-client), [§8 Repeated retrieval](../tech-design.md#8-repeated-retrieval-upsert-and-removal), [§1](../tech-design.md#1-settings-multiple-base-urls) (rules moved from feature 1); key decisions 4, 5, 6, 9, 10, 13, 14, 18, 19, 20.
Brief: [§2 Owners](../brief.md#2-owners-github-only), [§3 Repositories and projects](../brief.md#3-repositories-and-projects) (GitHub part), [§7 Data retrieval](../brief.md#7-data-retrieval-with-the-rest-client) (manual update of repositories, paging, error isolation), [§8 Repeated retrieval](../brief.md#8-repeated-retrieval-upsert-and-removal) (repositories).
Apps: GithubProjects, GithubProjects.Test. Branch: `spec/2026-10-20-github-repositories`.

## Goal

The user maintains GitHub owners and retrieves their repositories, including the token user's private ones, on demand.

## Definitions

- **Owner**: a GitHub user or organization whose repositories are retrieved, stored in Table "Owner GHP" with key (Base URL Code, Name). Only base URLs with Source Type `GitHub` can have owners.
- **Token user**: the GitHub account a base URL's token belongs to, as returned in `login` by `GET {base URL}/user`.
- **Repository**: a record in Table "Repository GHP", key (Base URL Code, Id), where Id is the GitHub repository `id`. The same table will hold Azure DevOps projects in feature 4.
- **Update of an owner**: retrieving all pages of the owner's repository list, and only then inserting, updating and removing repositories. One owner is one unit of work.
- **Update run**: one execution of "Update Repositories" for a set of owners.
- **Rate limit response**: a GitHub response with status 403 or 429 that has the header `x-ratelimit-remaining: 0` or a `retry-after` header.

## Functional requirements

### R1 — Owners

- R1.1 An admin can create, change and delete owners on Page "Owners GHP". Each owner has a Base URL Code, a Name (`Text[100]`) and an Owner Type (Enum "Owner Type GHP": `User`, `Organization`).
- R1.2 An owner can only belong to a base URL with Source Type `GitHub`. This is checked when the Base URL Code is validated and again on insert and modify with triggers.
- R1.3 The Name is trimmed of spaces and may only contain letters, digits, `-` and `_`. Any other character is refused, because the name becomes part of the request URL. A blank Name is refused.
- R1.4 Two owners of the same base URL cannot have the same Name, regardless of case.
- R1.5 An owner cannot be renamed (Base URL Code or Name). The error tells the user to delete the owner and create a new one. (Proposed 2026-10-20, to be confirmed: renaming would leave the stored repositories under the old account until the next update.)
- R1.6 Deleting an owner deletes its repositories.
- R1.7 The owner list shows the number of stored repositories per owner. Choosing it opens the repository list filtered on that owner.
- R1.8 Each owner has a Repository Sync option (Enum "Owner Sync GHP": `Include`, `Ignore`; `Include` for new owners) that the admin can change on the owner list (decided 2026-10-20).

### R2 — Base URL rules (moved from feature 1)

- R2.1 Deleting a base URL deletes its owners, and with them their repositories.
- R2.2 The Source Type of a base URL cannot change while it has owners. This is checked when Source Type is validated and again on modify with triggers.
- R2.3 Renaming a base URL's Code keeps its owners and repositories linked to it.
- R2.4 The base URL list has an action "Owners" that opens the owners of the current base URL.

### R3 — Requests to GitHub

- R3.1 All requests go through Codeunit "Rest Client", created with this app's own HTTP client handler, so outbound HTTP is allowed per extension on GithubProjects.
- R3.2 Every request sends `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28` and a `User-Agent` with this app's name and version. When the base URL has a token, it also sends `Authorization: Bearer <token>`; without a token, no Authorization header is sent.
- R3.3 Owner Type `Organization`: the repositories are requested from `{base URL}/orgs/{name}/repos`.
- R3.4 Owner Type `User` without a token: `{base URL}/users/{name}/repos`. `{base URL}/user` is not called.
- R3.5 Owner Type `User` with a token: `{base URL}/user` is called once per base URL per update run. If its `login` equals the owner's Name (case-insensitive), the repositories are requested from `{base URL}/user/repos?affiliation=owner&visibility=all`, so private repositories are included; otherwise from `{base URL}/users/{name}/repos`.
- R3.6 The first request of a list asks for 50 items per page (`per_page=50`). As long as a response has a `link` header with `rel="next"`, that URL is requested as given. The list is complete when a response has no next link.
- R3.7 A response that is not successful stops the update of that owner with an error that names the owner, the HTTP status code and reason phrase.

### R4 — Storing repositories

- R4.1 For each repository returned, the stored repository with the same Base URL Code and Id is updated (Owner, Name, Issues Enabled); if none exists, a repository is inserted with Source Type `GitHub` and Issue Sync `Include`.
- R4.2 An update never changes Issue Sync of an existing repository.
- R4.3 Issues Enabled stores GitHub's `has_issues`.
- R4.4 After all pages of an owner were retrieved successfully, the owner's stored repositories that were not returned are deleted.
- R4.5 If any request of an owner fails, none of that owner's repositories are inserted, changed or deleted.
- R4.6 Updating the same owner again with the same data gives no error and no duplicate.
- R4.7 Issue Sync (Enum "Issue Sync GHP", extensible, values `Include` and `Ignore`) can be changed by the user on the repository list. All other repository fields are read-only there. Users can delete repository lines; a deleted repository comes back the next time its owner is updated (decided 2026-10-20).
- R4.8 The repository list shows Source Type, Name, Issues Enabled and Issue Sync. Base URL Code and Owner are on the list but hidden; users can show them through personalization (decided 2026-10-20).

### R5 — Update runs and errors

- R5.1 Action "Update Repositories" on the owner list updates the selected owners.
- R5.2 Each owner is updated in its own unit of work: a failure of one owner rolls back only that owner, and the other owners are still updated.
- R5.3 When an owner gets a rate limit response, the remaining owners of the same base URL are skipped in this run, without requests. Owners of other base URLs are still updated. The skipped owners are reported in one failure for that base URL, with the time the limit resets.
- R5.4 A response with status 403 that is not a rate limit response is an ordinary failure of that owner only.
- R5.5 When all owners were updated, a message says how many owners were updated.
- R5.7 Owners with Repository Sync `Ignore` are skipped: no request is sent and their stored repositories are kept. The message of R5.5 also says how many owners were skipped this way. This also applies when such an owner is selected explicitly.
- R5.6 When one or more owners failed, the run ends with one error that lists the failed owners and their reasons (at most 10, followed by the number of further failures). The owners that succeeded keep their changes.

### R6 — Permission sets

- R6.1 "Projects User GHP" also gives read access to owners and repositories, lets the user change Issue Sync and delete repositories, and lets the user run "Update Repositories".
- R6.2 "Projects Admin GHP" also gives full access to owners.

## Non-functional requirements

- **Secrets**: the token stays `SecretText` until it is passed to Rest Client (`SecretStrSubstNo`, `bluace-compile.md` Rule 3); it never appears in an error or message. Request URLs in errors contain no token.
- **Tests**: no test sends a real request. HTTP goes through a mock handler injected through an `[InternalEvent]`; test base URLs use the `.invalid` host (`bluace-testing.md` Rule 2).
- **Extensibility**: code only tests Issue Sync with `<> Ignore`, so values added by an enum extension behave like `Include` (tech design §3).
- **Translations**: en-US and nl-NL, in the app and the test app.
- **Structure**: Bluace rules for helper codeunits, page code, RunTrigger and folders. No change to standard objects.
- **Performance**: repositories are read with `SetLoadFields`; the ids of one owner's list are kept in a `Dictionary`.

## Explicitly NOT included

- Issues, "Update Repositories and Issues", Delete Issues, and using Issue Sync and Issues Enabled to skip repositories (feature 3).
- Azure DevOps projects in the repository table, and the Azure DevOps parts of R2.1/R2.2 (feature 4).
- The job queue entry, "Create Job Queue Entry", and the lock that keeps a manual and a scheduled run apart (feature 6). Until then two manual runs can overlap; each owner's unit of work keeps the data consistent.
- Retrying requests after a rate limit within a run (GitHub asks not to; tech design §7).
- Fields other than those in R4.8 (e.g. private, fork, archived, description).
- Accepted risk (tech design §8): a repository transferred between two tracked owners can be deleted under the old owner and inserted again under the new one, losing its Issue Sync choice.
- Accepted risk: when a token is removed or replaced by one with less access, private repositories are no longer returned and are deleted on the next update (brief §2).
- GitHub Enterprise Server is supported through its base URL (`https://<host>/api/v3`) but only tested with the mock.
