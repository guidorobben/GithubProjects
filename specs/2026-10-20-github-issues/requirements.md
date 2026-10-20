# Requirements — GitHub issues

Roadmap: [3. GitHub issues](../roadmap.md#3-github-issues).
Tech design: [§3 Repositories and projects](../tech-design.md#3-repositories-and-projects), [§4 GitHub issues](../tech-design.md#4-github-issues), [§6 The shared Issue table](../tech-design.md#6-the-shared-issue-table), [§7 Data retrieval](../tech-design.md#7-data-retrieval-with-the-rest-client), [§8 Repeated retrieval](../tech-design.md#8-repeated-retrieval-upsert-and-removal), [§1](../tech-design.md#1-settings-multiple-base-urls) (github.com follow-up); key decisions 6, 9, 10, 13, 14, 15, 19, 20, 21.
Brief: [§3](../brief.md#3-repositories-and-projects) (Issue Sync, Delete Issues), [§4 GitHub issues](../brief.md#4-github-issues), [§6 The shared Issue table](../brief.md#6-the-shared-issue-table) (GitHub part), [§7](../brief.md#7-data-retrieval-with-the-rest-client) (manual actions for issues), [§8](../brief.md#8-repeated-retrieval-upsert-and-removal) (issues).
Apps: GithubProjects, GithubProjects.Test. Branch: `spec/2026-10-20-github-issues`.

## Goal

The user sees the open and closed issues of the repositories they choose to include.

## Definitions

- **Issue**: a record in Table "Issue GHP", key (Base URL Code, Id), where Id is GitHub's issue `id`. The same table will hold Azure DevOps work items in feature 5.
- **Pull request**: an item of GitHub's issue list that has a `pull_request` property. Pull requests are never stored.
- **Eligible repository**: a GitHub repository whose Issue Sync is not `Ignore`, whose Issues Enabled is Yes, and whose owner's Repository Sync is not `Ignore` (decided 2026-10-20).
- **Update of a repository's issues**: retrieving all pages of the repository's issue list, and only then inserting, updating and removing its issues. One repository is one unit of work.

## Functional requirements

### R1 — Issue table and list

- R1.1 Table "Issue GHP" has Base URL Code, Id (`BigInteger`), Source Type, Repository Id, Number, Type (Enum "Issue Type GHP": `Issue`, `User Story`, `Task`), Description (`Text[256]`), State (Enum "Issue State GHP": `Open`, `Closed`), Parent Id, Parent Description, Tree Root Id and Indentation. The last four are for Azure DevOps (feature 5) and stay empty for GitHub issues (decided 2026-10-20).
- R1.2 Page "Issues GHP" lists issues with Repository Name, Number, Description, State and Type. Base URL Code and Source Type are hidden. Users cannot add or change issues on the list.
- R1.3 Action "Issues" on the repository list opens the issues of the current repository. The issue count per repository is shown on the repository list and opens the same list.

### R2 — Retrieving issues

- R2.1 The issues of a repository are requested from `{base URL}/repos/{owner}/{repository name}/issues?state=all`, with 50 items per page, following `link` `rel="next"` until the last page (as for repositories, feature 2).
- R2.2 Items with a `pull_request` property are skipped.
- R2.3 For each remaining item, the stored issue with the same Base URL Code and Id is updated (Repository Id, Number, Description, State); if none exists, it is inserted with Source Type `GitHub` and Type `Issue`. Description is the `title`, cut to 256 characters.
- R2.4 State `open` becomes `Open`, `closed` becomes `Closed`. Any other value fails the repository with an error naming the value.
- R2.5 After all pages of a repository were retrieved successfully, the repository's stored issues that were not returned are deleted.
- R2.6 If any request of a repository fails, none of its issues are inserted, changed or deleted.
- R2.7 Updating the same repository again with the same data gives no error and no duplicate.

### R3 — Which repositories are updated

- R3.1 Only eligible repositories are updated. A repository that is not eligible gets no request and keeps its stored issues. Being skipped is not a failure.
- R3.2 Code tests Issue Sync only with `<> Ignore`, so values added by an enum extension behave like `Include` (tech design §3).
- R3.3 A repository stores whether it is a fork (GitHub's `fork`, No when missing), shown as "Fork" on the repository list. A fork that is inserted by a repository update gets Issue Sync `Ignore`; the user can set it to `Include`. A stored repository keeps its Issue Sync when it turns out to be a fork, because an update never changes Issue Sync (feature 2, R4.2) (decided 2026-10-20).

### R4 — Actions and runs

- R4.1 Action "Update Issues" on the repository list updates the issues of the selected repositories.
- R4.2 Action "Update Repositories and Issues" on the owner list first updates the repositories of each selected owner (feature 2), then the issues of that owner's eligible repositories.
- R4.3 Each repository's issue update is its own unit of work, like each owner's repository update: a failure rolls back only that repository, and the others are still updated.
- R4.4 A GitHub rate limit on a base URL skips the remaining owners and repositories of that base URL in the same run, as in feature 2. Other base URLs are still updated.
- R4.5 When nothing failed, a message says how many repositories had their issues updated and how many were skipped (with the owner count first when owners were updated too). When repositories were skipped, it also says how many for each reason: Issue Sync set to Ignore, Issues Enabled set to No, and the owner's Repository Sync set to Ignore (decided 2026-10-20).
- R4.6 When something failed, the run ends with one error that lists the failed owners and repositories (at most 10 lines, as in feature 2). Units that succeeded keep their changes.

### R5 — Deleting issues

- R5.1 Action "Delete Issues" on the repository list asks for confirmation and then deletes the stored issues of the selected repositories. Answering No deletes nothing.
- R5.2 Setting a repository's Issue Sync to `Ignore` keeps its stored issues (brief §3).
- R5.3 Deleting a repository deletes its issues.

### R6 — github.com base URL (follow-up from feature 2)

- R6.1 A base URL whose host is `github.com` or `www.github.com` is refused with an error that suggests `https://api.github.com`. This is checked on validate and again on insert and modify.

### R7 — Permission sets

- R7.1 "Projects User GHP" also reads issues, runs both new update actions, and deletes issues with "Delete Issues".
- R7.2 Issues are only inserted and modified by the update (indirect permission).

## Non-functional requirements

- **Tests**: no real requests; the mock handler of feature 2 is reused (`bluace-testing.md` Rule 2).
- **Secrets**: as in feature 2 — the token stays `SecretText`; no token in errors or URLs.
- **Performance**: issues are read with `SetLoadFields`; the ids of one repository's list are kept in a `Dictionary`.
- **Translations**: en-US and nl-NL in the app and the test app.
- **Structure**: Bluace rules; Repository gets its helper codeunit now. No change to standard objects.

## Explicitly NOT included

- Azure DevOps work items, the tree view (`ShowAsTree`), Parent Id and Parent Description logic (feature 5). The fields exist but stay empty.
- Azure DevOps projects (feature 4); the update actions skip repositories whose Source Type is not GitHub.
- The job queue and the lock between manual and scheduled runs (feature 6).
- Issue body, comments, labels, assignees and `state_reason`; only the fields in R1.1 are stored (brief §6).
- Accepted risk (tech design §8): an issue transferred to another tracked repository can be deleted under the old repository and inserted again under the new one in the same run.
- Accepted risk: a renamed or transferred repository gets its new name only at the next repository update; until then its issue request may be redirected by GitHub or fail with 404 (checked in M2).
