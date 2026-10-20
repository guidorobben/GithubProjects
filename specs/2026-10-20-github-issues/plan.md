# Plan — GitHub issues

Implements [requirements.md](requirements.md) as decided in [tech-design.md §3, §4, §6, §7, §8](../tech-design.md#4-github-issues).
App: GithubProjects, a per-tenant extension (ID range 80000–80099, runtime 17.0, application and platform 28.0.0.0; symbols 28.5). Standard objects are not modified.

## Naming and structure

- Object names end with ` GHP`, captions have no suffix, helpers and update codeunits are `Access = Internal`, pages call table procedures only, every write states RunTrigger (Bluace rules, as in features 1 and 2).
- Folders:

```
GithubProjects/src/
├── BaseURL/      (helper: github.com check)
├── GitHub/       (unchanged client; reused)
├── Issue/
│   ├── Issue.Table.al
│   ├── IssueState.Enum.al
│   ├── IssueType.Enum.al
│   ├── IssueUpdate.Codeunit.al
│   └── Issues.Page.al
├── Owner/        (Owners page action; Owner Helper delegates to Update Run)
├── PermissionSets/
├── Repository/   (Repository Helper; table and page get actions and a FlowField)
└── Update/
    └── UpdateRun.Codeunit.al
```

- **Deviations from the tech design**, to be written back in the Docs step:
  1. The run loop moves from Codeunit "Owner Helper GHP" to a new Codeunit "Update Run GHP", so owner updates, repository issue updates and (in feature 6) the job queue share one failure list, one rate-limit state and one message (decided 2026-10-20).
  2. An owner with Repository Sync `Ignore` also skips its repositories' issues (decided 2026-10-20).
  3. The Issue table gets all fields of §6 now, including those for Azure DevOps (decided 2026-10-20).
  4. Issue gets a FlowField "Repository Name" and Repository a FlowField "No. of Issues", so the lists show which repository an issue belongs to.
  5. The rate-limit line becomes `%1: GitHub rate limit reached; %3 owner(s) and %4 repository(ies) skipped. The limit resets at %2.` Feature 2's tests E2/E3 are updated.
  6. The issues URL uses the repository's stored Owner and Name: GitHub treats both as case-insensitive (GitHub docs, "List repository issues").

## Objects

| Type | ID | Name | Caption | File | Folder |
| --- | --- | --- | --- | --- | --- |
| Enum | 80004 | Issue Type GHP | Issue Type | IssueType.Enum.al | src/Issue |
| Enum | 80005 | Issue State GHP | Issue State | IssueState.Enum.al | src/Issue |
| Table | 80003 | Issue GHP | Issue | Issue.Table.al | src/Issue |
| Page | 80003 | Issues GHP | Issues | Issues.Page.al | src/Issue |
| Codeunit | 80006 | Repository Helper GHP | – | RepositoryHelper.Codeunit.al | src/Repository |
| Codeunit | 80007 | Issue Update GHP | – | IssueUpdate.Codeunit.al | src/Issue |
| Codeunit | 80008 | Update Run GHP | – | UpdateRun.Codeunit.al | src/Update |

Changed: Table "Repository GHP" (FlowField, `OnDelete`, procedures), Page "Repositories GHP" (actions), Table "Owner GHP" and Page "Owners GHP" (new procedure and action), Codeunit "Owner Helper GHP" (delegates), Codeunit "Base URL Helper GHP" (github.com check), both permission sets.

## Enums (R1.1)

- "Issue Type GHP": `Extensible = false`; `0 Issue`, `1 "User Story"`, `2 Task`.
- "Issue State GHP": `Extensible = false`; `0 Open`, `1 Closed`.

## Table "Issue GHP" (R1.1)

`DataClassification = CustomerContent`, `AllowInCustomizations = AsReadOnly`, `LookupPageId`/`DrillDownPageId` = Page "Issues GHP".

| No. | Name | Type | Properties |
| --- | --- | --- | --- |
| 1 | Base URL Code | Code[20] | `NotBlank`; `TableRelation = "Base URL GHP"` |
| 2 | Id | BigInteger | GitHub issue `id` (int64) |
| 3 | Source Type | Enum "Source Type GHP" | |
| 4 | Repository Id | Code[50] | `TableRelation = "Repository GHP".Id where("Base URL Code" = field("Base URL Code"))` |
| 5 | Number | Integer | GitHub `number` (the `#123`) |
| 6 | Type | Enum "Issue Type GHP" | |
| 7 | Description | Text[256] | `title`, stored with `CopyStr` (key decision 15) |
| 8 | State | Enum "Issue State GHP" | |
| 9 | Parent Id | BigInteger | feature 5 |
| 10 | Parent Description | Text[256] | FlowField `lookup("Issue GHP".Description where("Base URL Code" = field("Base URL Code"), Id = field("Parent Id")))`; feature 5 |
| 11 | Tree Root Id | BigInteger | feature 5 |
| 12 | Indentation | Integer | feature 5 |
| 20 | Repository Name | Text[100] | FlowField `lookup("Repository GHP".Name where("Base URL Code" = field("Base URL Code"), Id = field("Repository Id")))` |

Keys: `PK` (Base URL Code, Id); `RepositoryNumber` (Base URL Code, Repository Id, Number) for the page and pruning; `Tree` (Base URL Code, Repository Id, Tree Root Id, Indentation, Id) for feature 5 (tech design §6). No table procedures yet; no helper codeunit (as Repository in feature 2).

## Page "Issues GHP" (R1.2)

`PageType = List`, `UsageCategory = Lists`, `Editable = false`, `SourceTableView = sorting("Base URL Code", "Repository Id", Number)`. Fields: Repository Name, Number, Description, State, Type; Base URL Code and Source Type with `Visible = false`.

## Repository changes (R1.3, R4.1, R5)

- Field 8 "No. of Issues" (Integer, FlowField `count("Issue GHP" where("Base URL Code" = field("Base URL Code"), "Repository Id" = field(Id)))`, `Editable = false`), shown on the page with drill-down.
- Field 9 "Fork" (Boolean), shown on the page, not editable (R3.3). "Owner Update GHP" `UpsertRepositories` reads `fork` through `GetFork` (false when missing or null), stores it on insert and modify, and on insert only sets Issue Sync to `Ignore` for a fork.
- `OnDelete` → `RepositoryHelper.DeleteIssues(Rec)` (R5.3; tech design §3).
- Table procedures (call the helper): `UpdateIssues()` (selection, R4.1), `DeleteIssuesWithConfirmation()` (selection, R5.1).
- Page actions: `UpdateIssues` (Caption 'Update Issues', Image `Refresh`), `DeleteIssues` (Caption 'Delete Issues', Image `Delete`), both `CurrPage.SetSelectionFilter(Repository)` → table procedure → `CurrPage.Update(false)`; `Issues` (Image `List`, `RunObject = page "Issues GHP"`, `RunPageLink = "Base URL Code" = field("Base URL Code"), "Repository Id" = field(Id)`).

## Codeunit "Repository Helper GHP" (R5)

`Access = Internal`, `Permissions = tabledata "Issue GHP" = rd`.
- `DeleteIssues(var Repository)`: issues with the repository's Base URL Code and Repository Id → `DeleteAll(true)`.
- `DeleteIssuesWithConfirmation(var Repository)`: count the selection; `ConfirmManagement.GetResponseOrDefault(StrSubstNo(DeleteIssuesQst, Count), false)`; on Yes, `DeleteIssues` for each selected repository. Verified (source): Codeunit "Confirm Management" `GetResponseOrDefault` (feature 1).
- `UpdateIssues(var Repository)`: `UpdateRun.UpdateIssues(Repository)`.

## Codeunit "Issue Update GHP" (R2)

`Access = Internal`, `TableNo = "Repository GHP"`, `Permissions = tabledata "Base URL GHP" = r, tabledata "Issue GHP" = rimd`. Same pattern as "Owner Update GHP" (feature 2):
1. Get the base URL; `GitHubClient.Initialize(BaseURL)` (global client, so `GetRateLimitReset` works after a failed run).
2. `GitHubClient.GetAllPages(StrSubstNo(IssuesLbl, BaseURL.URL, Repository.Owner, Repository.Name), Items)` with `IssuesLbl = '%1/repos/%2/%3/issues?state=all'` (Locked). `GetAllPages` adds `&per_page=50` (verified (source): `GitHubClient.Codeunit.al` `AddPerPage`).
3. For each item: skip when `Contains('pull_request')` (R2.2); map `state` (R2.4, `Error(UnknownStateErr, Value)` otherwise); upsert by (Base URL Code, Id) (R2.3); remember the Id in `Dictionary of [BigInteger, Boolean]`.
4. Prune the repository's issues not seen (key RepositoryNumber, `SetLoadFields(Id)`) with `Delete(true)` (R2.5).
Everything is fetched before the first write (R2.6, tech design §8).

## Codeunit "Update Run GHP" (R3, R4)

`Access = Internal`. One instance per run; holds the runner instances ("Owner Update GHP", "Issue Update GHP"), `RateLimitResets: Dictionary of [Code[20], Text]`, skip counters per base URL, `Failures: List of [Text]`, and the counts.

- `UpdateOwners(var Owner; WithIssues: Boolean)`: copies the selection to a temporary table, leaving out owners with Repository Sync `Ignore` (counted, feature 2). For each owner: rate-limited base URL → skip; else `Commit()` and `OwnerUpdate.Run`. With `WithIssues` and a successful owner: `UpdateIssuesOfOwner(Owner)` — the owner's eligible GitHub repositories, each through `RunIssueUpdate`.
- `UpdateIssues(var Repository)`: copies the selection (GitHub repositories only); each eligible repository through `RunIssueUpdate`; others counted as skipped.
- `local IsEligible(var Repository): Boolean` (R3.1): `"Issue Sync" <> Ignore`, `"Issues Enabled"`, and the owner's Repository Sync `<> Ignore` (owner read with `SetLoadFields`).
- `local RunIssueUpdate(var Repository)`: rate-limited base URL → skip; else `Commit()`, `if not IssueUpdate.Run(...)` → failure line `RepositoryFailedLbl` (`%1 %2/%3: %4`) or rate-limit registration.
- `Finish()`: rate-limit lines, then `Error(UpdateFailedErr, ...)` with at most 10 lines (feature 2's `FormatFailures`, moved here), or — only `if GuiAllowed()` — the message for the run type (R4.5).
- Codeunit "Owner Helper GHP" `UpdateRepositories` becomes `UpdateRun.UpdateOwners(Owner, false)`; new `UpdateRepositoriesAndIssues` → `UpdateRun.UpdateOwners(Owner, true)`. Labels for runs move from the owner helper to this codeunit (XLIFF ids change; translations regenerated).

## Base URL change (R6.1)

In "Base URL Helper GHP" `ValidateUrl` and `CheckUrl`, after the https check: take the host (text after `https://` up to the first `/`, lower case); if it is `github.com` or `www.github.com` → `Error(GitHubWebsiteErr, URL)`.

## Labels (new or changed)

| Name | Text | Comment |
| --- | --- | --- |
| GitHubWebsiteErr | The URL %1 is the GitHub website. For github.com, use https://api.github.com. | %1 = URL |
| UnknownStateErr | GitHub returned the unknown issue state %1. | %1 = state |
| DeleteIssuesQst | Do you want to delete the stored issues of %1 repository(ies)? | %1 = number of repositories |
| RepositoryFailedLbl | %1 %2/%3: %4 | %1 = base URL code, %2 = owner, %3 = repository, %4 = error |
| RateLimitLbl (changed) | %1: GitHub rate limit reached; %3 owner(s) and %4 repository(ies) skipped. The limit resets at %2. | %1 = base URL code, %2 = date and time, %3/%4 = numbers |
| IssuesUpdatedMsg | The issues of %1 repository(ies) were updated. %2 repository(ies) were skipped. | %1, %2 = numbers |
| RepositoriesAndIssuesUpdatedMsg | The repositories of %1 owner(s) and the issues of %2 repository(ies) were updated. %3 owner(s) and %4 repository(ies) were skipped. | %1–%4 = numbers |
| UpdateFailedErr (changed) | The update failed for %1 owner(s) or repository(ies):\%2 | %1 = number, %2 = list |

`UpdatedMsg` and `UpdatedWithIgnoredMsg` (feature 2) stay for owner-only runs.

## Test app (automated tests)

Reuses "Mock Http Handler GHP" and "Library - GitHub GHP" (extended with `IssueJson(Id, Number, Title, State)`, `PullRequestJson(...)`, `IssuesUrl(BaseURL, Owner, Repo)`, `CreateIssue(...)`). Every UT codeunit has `TestPermissions = Disabled`; "Projects Test GHP" gets X on the new codeunits.

| Type | ID | Name | Acceptance |
| --- | --- | --- | --- |
| Codeunit | 50015 | UT Issue Update GHP | A |
| Codeunit | 50016 | UT Issue Eligibility GHP | B |
| Codeunit | 50017 | UT Issue Runs GHP | C |
| Codeunit | 50018 | UT Issue Delete GHP | D |
| Codeunit | 50019 | UT GitHub Website URL GHP | E |
| Codeunit | 50020 | UT Issue Perm. GHP | F |
| Codeunit | 50021 | UT Issue UI GHP | P |
| Codeunit | 50009 | UT Repository Update GHP (feature 2, extended) | H |

"Library - GitHub GHP" also gets `ForkJson(Id, Name)` for section H.

Feature 2's E2/E3 are updated for the changed rate-limit label; its UpdateFailedErr assertions use line labels only, so they keep working.

## Permission sets (R7)

| Name | Added | Why |
| --- | --- | --- |
| Projects User GHP | `tabledata "Issue GHP" = RimD`, `table`/`page` X for issues, `codeunit` X for "Repository Helper GHP", "Issue Update GHP", "Update Run GHP" | Users run the updates (indirect insert/modify through "Issue Update GHP") and delete issues (Delete Issues, deleting a repository). |
| Projects Admin GHP | – | Includes the user set. |

## Traceability

| Requirement | Plan section |
| --- | --- |
| R1.1–R1.3 | Enums, Issue table, Issues page, Repository changes |
| R2.1–R2.7 | Issue Update |
| R3.1–R3.2 | Update Run `IsEligible` |
| R3.3 | Repository changes (Fork) |
| R4.1–R4.6 | Update Run, Owner Helper, Repository Helper, pages |
| R5.1–R5.3 | Repository Helper, Repository `OnDelete` |
| R6.1 | Base URL change |
| R7.1–R7.2 | Permission sets |
