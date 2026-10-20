# Acceptance — GitHub issues

Defines done for [requirements.md](requirements.md).

- **Sections A–F, H and P are automated tests** in GithubProjects.Test (see [plan.md](plan.md#test-app-automated-tests)). They run in the AL Test Tool and the AL-Go pipeline; a pass in the AL MCP runner is not final, because it does not fail on unhandled dialogs (`bluace-testing.md` Rule 1). HTTP goes to "Mock Http Handler GHP"; base URLs use the `.invalid` host.
- **Section M is the short manual list**: the real GitHub API.

## Conventions for the automated tests

- **Base URLs, owners**: GH1 (GitHub, no token unless stated), owner ORG (`org-a`, Organization) and USR (`user-b`, User), as in feature 2.
- **Repositories** (created directly, without a request): REPO-A (`repo-a`, Id 201, owner ORG, Issues Enabled Yes, Issue Sync Include), REPO-B (`repo-b`, Id 202, owner ORG), REPO-U (`repo-u`, Id 203, owner USR).
- **Issue JSON**: `I1` = id 9001, number 1, title `First`, state `open`; `I2` = id 9002, number 2, title `Second`, state `closed`; `PR` = id 9003, number 3, with a `pull_request` property.
- **Issues URL**: `{GH1}/repos/org-a/repo-a/issues?state=all&per_page=50`.
- **Requests**: as in feature 2 — exact URLs in order; "No request" means none; `AssertAllResponsesUsed()` after each test.
- **Messages and errors** are asserted against test labels with the app's English text (`bluace-testing.md` Rule 7).

## A. Retrieving issues (R2)

| # | Given | When | Then |
| --- | --- | --- | --- |
| A1 | REPO-A; mock: I1, I2, PR | Issues of REPO-A are updated | Request: the issues URL. Issues 9001 (Number 1, `First`, Open) and 9002 (Number 2, `Second`, Closed) exist with Repository Id 201, Source Type GitHub, Type Issue; 9003 does not exist (R2.1–R2.4) |
| A2 | REPO-A; mock: page 1 (I1) with a next link to page 2 (I2) | Issues of REPO-A are updated | Two requests; 9001 and 9002 exist (R2.1) |
| A3 | 9001 stored as `Old title`, Open; mock: I1 with state `closed` | Updated | 9001 has `First`, Closed (R2.3) |
| A4 | 9001 and 9002 stored for REPO-A; mock: I1 only | Updated | 9001 exists; 9002 deleted (R2.5) |
| A5 | 9001 stored as `Old title`; mock: page 1 with I2 and a next link, page 2 → 500 | Updated | Run error names `org-a/repo-a`; 9001 still `Old title`; 9002 not inserted (R2.6) |
| A6 | Updated once with I1, I2 | Updated again with the same data | No error; exactly 2 issues for REPO-A (R2.7) |
| A7 | Mock: an issue with state `unknown` | Updated | Run error contains `UnknownStateErr` with `unknown`; nothing stored (R2.4) |
| A8 | 9001 stored for REPO-B; mock for REPO-A: I1 | REPO-A updated | 9001 now has Repository Id 201 (transfer within the base URL, R2.3) |
| A9 | Mock: an issue with a title of 300 characters | Updated | Description = first 256 characters (R2.3) |

## B. Which repositories (R3)

| # | Given | When | Then |
| --- | --- | --- | --- |
| B1 | REPO-A with Issue Sync Ignore and 9001 stored | Issues of REPO-A are updated | No request; 9001 still exists; message `IssuesUpdatedMsg` with 0 and 1 (R3.1, R5.2) |
| B2 | REPO-A with Issues Enabled No | Updated | No request; message with 0 and 1 (R3.1) |
| B3 | ORG with Repository Sync Ignore; REPO-A of ORG | Issues of REPO-A are updated | No request; message with 0 and 1 (R3.1, decided 1A) |
| B4 | REPO-A eligible, REPO-B Ignore; mock for REPO-A: I1 | Both updated | One request; message with 1 and 1 (R3.1, R4.5) |

## C. Runs (R4)

| # | Given | When | Then |
| --- | --- | --- | --- |
| C1 | ORG; mock: repository list with REPO-A (201) and REPO-B (202, `has_issues` false), then issues of REPO-A: I1 | "Update Repositories and Issues" on ORG | Requests: ORG's repository list, then REPO-A's issues only. 9001 exists. Message `RepositoriesAndIssuesUpdatedMsg` with 1, 1, 0, 1 (R4.2) |
| C2 | REPO-A (404) and REPO-B (mock: I2) | Issues of both are updated | 9002 exists; run error with a line `RepositoryFailedLbl` naming `org-a/repo-a` and 404 (R4.3, R4.6) |
| C3 | REPO-A (rate limit 403, remaining 0) and REPO-B on GH1; REPO-C on GH2 (mock: I1) | Issues of all three are updated | No request for REPO-B; REPO-C updated; error has the rate-limit line for GH1 with 0 owners and 1 repository skipped (R4.4) |
| C4 | ORG with a repository-list rate limit; WithIssues | "Update Repositories and Issues" on ORG and USR (both on GH1) | Only ORG's list is requested; no issue requests (R4.4) |
| C5 | ORG updates fine but REPO-A's issues fail (404) | "Update Repositories and Issues" on ORG | ORG's repositories are stored; the error names `org-a/repo-a` (R4.3, R4.6) |

## D. Deleting issues (R5)

| # | Given | When | Then |
| --- | --- | --- | --- |
| D1 | 9001, 9002 for REPO-A; 9003 for REPO-B | "Delete Issues" on REPO-A, confirmation Yes (question `DeleteIssuesQst` with 1) | 9001, 9002 deleted; 9003 kept (R5.1) |
| D2 | Same | Confirmation No | Nothing deleted (R5.1) |
| D3 | 9001 for REPO-A | REPO-A is deleted with triggers | 9001 deleted (R5.3) |
| D4 | 9001 for REPO-A | REPO-A's Issue Sync is set to Ignore and modified | 9001 still exists (R5.2) |

## E. github.com base URL (R6)

| # | Given | When | Then |
| --- | --- | --- | --- |
| E1 | A new base URL | URL validated with `https://github.com/guidorobben` | Error `GitHubWebsiteErr` with that URL (R6.1) |
| E1a | A new base URL | URL validated with `https://WWW.GitHub.com` | Error `GitHubWebsiteErr` (R6.1) |
| E2 | A new base URL | URL `https://github.com` assigned without validation, inserted with triggers | Error `GitHubWebsiteErr`; no record (R6.1) |
| E3 | A new base URL | URL validated with `https://github.example.invalid/api/v3` and `https://api.github.invalid` | No error (R6.1). `.invalid` hosts, so real base URLs in the company cannot collide with the duplicate check. |

## F. Permissions (R7)

| # | Given | When | Then |
| --- | --- | --- | --- |
| F1 | REPO-A; mock: I1; "Projects User GHP" | Issues of REPO-A are updated | 9001 exists (R7.1, R7.2) |
| F2 | 9001 for REPO-A; "Projects User GHP" | "Delete Issues" with Yes | 9001 deleted (R7.1) |
| F3 | 9001; "Projects User GHP" | 9001's Description is changed and modified directly | An error; Description unchanged (R7.2) |

## P. Pages — TestPage

| # | Given | When | Then |
| --- | --- | --- | --- |
| P1 | 9001, 9002 for REPO-A; 9003 for REPO-B | On "Repositories", REPO-A's "Issues" action | The list shows 9001 and 9002 with Repository Name `repo-a`, not 9003 (R1.2, R1.3) |
| P2 | 9001, 9002 for REPO-A | "Repositories" opened | No. of Issues on REPO-A = 2 (R1.3) |
| P3 | REPO-A; mock: I1 | On "Repositories", REPO-A is the current line, "Update Issues" | 9001 exists; message `IssuesUpdatedMsg` with 1 and 0 (R4.1) |
| P4 | 9001 for REPO-A | "Issues" opened for editing (`OpenEdit`, so the page's own setting is tested, not view mode) | The page is not editable (R1.2) |
| P5 | ORG; mock: list with REPO-A, issues I1 | On "Owners", ORG current, "Update Repositories and Issues" | 9001 exists (R4.2) |

## H. Forks (R3.3)

In "UT Repository Update GHP" (feature 2's D-tests), with ORG on GH1.

| # | Given | When | Then |
| --- | --- | --- | --- |
| H1 | ORG returns fork 104 (`"fork":true`) and R1 | ORG's repositories are updated | 104 has Fork Yes and Issue Sync Ignore; 101 has Fork No and Issue Sync Include (R3.3) |
| H2 | 104 stored with Fork No and Issue Sync Include; ORG returns 104 as a fork | Updated | 104 has Fork Yes and keeps Issue Sync Include (R3.3) |

## M. Manual checks

On `tm2023w2v2-nl`, with base URL `https://api.github.com` and a token.

| # | Check | Pass when |
| --- | --- | --- |
| M1 | Owner `guidorobben` (User); "Update Repositories and Issues" | Issues of `BluaceWorkflowEditor` appear, open and closed, without pull requests; the counts match GitHub's Issues tab (open + closed) |
| M2 | Rename a test repository on GitHub, then "Update Issues" on it before "Update Repositories" | Record what happens (redirect or 404); then "Update Repositories" and "Update Issues" work again (observation for the guide) |
| M3 | Base URL with `https://github.com` | Refused with the hint to `https://api.github.com` |
| M4 | "Update Repositories" on an owner with a fork in GitHub | Repositories that are forks in GitHub show Fork = Yes. Forks added in this run have Issue Sync = Ignore; forks that were already stored keep their Issue Sync |

## G. Quality gates

- G1 Both apps compile without errors and without warnings under the workspace analyzers and the Bluace ruleset.
- G2 All automated tests pass in the AL Test Tool or the AL-Go pipeline, including features 1 and 2.
- G3 All user-facing texts are Labels or Captions; en-US and nl-NL complete in the app and the test app.
- G4 No token in errors, messages or URLs; never unwrapped.
- G5 No standard object and no other app is modified.
- G6 Section M passed, results recorded in the PR.
- G7 After merge: tech design, roadmap (`done`), user guide and changelog updated.

## Not covered here

- Azure DevOps projects (feature 4), work items and the tree view (feature 5), job queue and lock (feature 6).
