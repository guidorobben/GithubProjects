# Acceptance — GitHub repositories

Defines done for [requirements.md](requirements.md).

- **Sections A–F and P are automated tests** in GithubProjects.Test (see [plan.md](plan.md#test-app-automated-tests)). They run in the AL Test Tool and the AL-Go pipeline. The AL MCP runner may be used while developing, but it does not fail on unhandled dialogs, so a pass there is not final (`bluace-testing.md` Rule 1). No test sends a real request: HTTP goes to "Mock Http Handler GHP", and base URLs use the `.invalid` host.
- **Section M is the short manual list.** It covers what the mock cannot prove: the real GitHub API and the per-extension HTTP setting.

## Conventions for the automated tests

- **Base URLs**: **GH1** and **GH2**, Source Type GitHub, URLs `https://gh1-<random>.invalid` and `https://gh2-<random>.invalid`; **AZ**, Source Type Azure DevOps. "With token" means a dummy token is set (feature 1).
- **Owners**: **ORG** (Organization, name `org-a`), **USR** (User, name `user-b`), **ME** (User, name `Me-Login`) on GH1 unless stated; **OTHER** (Organization, `org-c`) on GH2.
- **Repository JSON**: `R1` = `{"id":101,"name":"repo-one","has_issues":true}`, `R2` = `{"id":102,"name":"repo-two","has_issues":false}`, `R3` = `{"id":103,"name":"repo-three","has_issues":true}`.
- **Requests**: the mock records each request in order. "Requests: X, Y" means exactly those URLs, in that order. "No request" means the mock recorded nothing. After every test, `AssertNoMoreResponses()` proves every queued response was used.
- **Headers**: the mock reports whether `Authorization`, `Accept`, `X-GitHub-Api-Version` and `User-Agent` were present on each request.
- **Messages** are asserted in full against test labels with the app's English text (`bluace-testing.md` Rule 7).
- **Permissions**: all sections run with the test user's own permissions, except F (Permissions Mock with the set under test plus "Projects Test GHP").
- Test procedure names start with the ID (`bluace-testing.md` Rule 5).

## A. Owners (R1)

| # | Given | When | Then |
| --- | --- | --- | --- |
| A1 | GH1 | An owner with Base URL Code GH1, Name `org-a`, Owner Type Organization is inserted with triggers | It exists (R1.1) |
| A2 | AZ | An owner validates Base URL Code AZ | Error `OwnerNeedsGitHubErr` with AZ's code (R1.2) |
| A2a | AZ | An owner with Base URL Code AZ assigned without validation is inserted with triggers | Error `OwnerNeedsGitHubErr`; no owner exists (R1.2) |
| A3 | GH1 | Name is validated with `  org-a  ` | Name = `org-a` (R1.3) |
| A3a | GH1 | Name is validated with `../org` | Error `InvalidOwnerNameErr` with `../org` (R1.3) |
| A3b | GH1 | Name `org a` assigned without validation, inserted with triggers | Error `InvalidOwnerNameErr`; no owner exists (R1.3) |
| A4 | ORG exists on GH1 | Another owner on GH1 validates Name `ORG-A` | Error `DuplicateOwnerErr` with `ORG-A` and GH1 (R1.4) |
| A4a | ORG exists on GH1 | An owner on GH2 validates Name `org-a` | No error (R1.4: per base URL) |
| A5 | ORG | ORG is renamed to `org-x` | Error `OwnerRenameErr`; ORG still exists under its name (R1.5) |
| A6 | ORG with repositories 101 and 102; OTHER with 103 | ORG is deleted with triggers | 101 and 102 are deleted; 103 remains (R1.6) |
| A7 | ORG with repositories 101 and 102 | No. of Repositories is calculated | 2 (R1.7) |

## B. Base URL rules (R2)

| # | Given | When | Then |
| --- | --- | --- | --- |
| B1 | GH1 with token, ORG with 101, USR with 102; GH2 with OTHER and 103 | GH1 is deleted with triggers | No owner and no repository of GH1 remain; GH1 has no token; OTHER and 103 remain (R2.1) |
| B2 | GH1 with ORG | GH1 validates Source Type Azure DevOps | Error `SourceTypeInUseErr` with GH1's code (R2.2) |
| B2a | GH1 with ORG | Source Type is assigned Azure DevOps without validation, then modified with triggers | Error `SourceTypeInUseErr`; GH1 is still GitHub (R2.2) |
| B3 | GH2 without owners | GH2 validates Source Type Azure DevOps and is modified | No error (R2.2) |
| B4 | GH1 with ORG and repository 101 | GH1 is renamed to a new code | ORG and 101 have the new Base URL Code (R2.3) |

## C. Requests to GitHub (R3)

| # | Given | When | Then |
| --- | --- | --- | --- |
| C1 | GH1 with token; ORG; mock: page with R1 | ORG is updated | Requests: `{GH1}/orgs/org-a/repos?per_page=50`. Authorization, Accept, X-GitHub-Api-Version and User-Agent present (R3.2, R3.3) |
| C2 | GH1 without token; USR; mock: page with R1 | USR is updated | Requests: `{GH1}/users/user-b/repos?per_page=50` (no `/user`). Authorization absent; Accept, X-GitHub-Api-Version, User-Agent present (R3.2, R3.4) |
| C3 | GH1 with token; ME; mock: `/user` → `{"login":"me-login"}`, then page with R1 | ME is updated | Requests: `{GH1}/user`, `{GH1}/user/repos?affiliation=owner&visibility=all&per_page=50` (R3.5, case-insensitive) |
| C4 | GH1 with token; USR; mock: `/user` → `{"login":"someone-else"}`, then page with R1 | USR is updated | Requests: `{GH1}/user`, `{GH1}/users/user-b/repos?per_page=50` (R3.5) |
| C5 | GH1 with token; USR and ME; mock: `/user` once, then a page for each | Both are updated in one run | Requests: `{GH1}/user` exactly once, then the two lists (R3.5; proves the per-run cache) |
| C6 | GH1; ORG; mock: page 1 (R1) with link `<{GH1}/x?page=2>; rel="next", <{GH1}/x?page=3>; rel="last"`, page 2 (R2) with a next link to page 3, page 3 (R3) without link | ORG is updated | Requests: the first URL, `{GH1}/x?page=2`, `{GH1}/x?page=3`; repositories 101, 102, 103 exist (R3.6) |
| C7 | Base URL `https://ghe-<random>.invalid/api/v3`; ORG on it; mock: page with R1 | ORG is updated | Requests: `https://ghe-<random>.invalid/api/v3/orgs/org-a/repos?per_page=50` (R3.3, GitHub Enterprise Server form) |
| C8 | GH1; ORG; mock: 404 "Not Found" | ORG is updated in a run | The run's error contains `RequestFailedErr` with the URL, 404 and `Not Found` (R3.7) |

## D. Storing repositories (R4)

| # | Given | When | Then |
| --- | --- | --- | --- |
| D1 | GH1; ORG; no repositories; mock: R1, R2 | ORG is updated | 101 (`repo-one`, Issues Enabled Yes) and 102 (`repo-two`, Issues Enabled No) exist with Owner `org-a`, Source Type GitHub, Issue Sync Include (R4.1, R4.3) |
| D2 | D1 done; mock: R1, R2 again | ORG is updated again | No error; exactly 2 repositories for ORG (R4.6) |
| D3 | 101 stored as `old-name`, Issue Sync Ignore; mock: R1 | ORG is updated | 101 has Name `repo-one` and Issue Sync Ignore (R4.1, R4.2) |
| D4 | 101 and 102 stored for ORG; mock: R1 only | ORG is updated | 101 exists; 102 is deleted (R4.4) |
| D5 | 101 and 102 stored for ORG (101 named `old-name`); mock: page 1 with R3 and a next link, page 2 → 500 | ORG is updated | 101 still `old-name`; 102 still exists; 103 not inserted (R4.5) |
| D6 | 101 for ORG, 103 for OTHER; mock for ORG: R1 only | ORG is updated | 103 still exists (R4.4: prune per owner) |
| D7 | 101 stored for USR; mock for ORG: R1 | ORG is updated | 101 now has Owner `org-a`; Issue Sync unchanged (R4.1, accepted transfer case) |

## E. Update runs and errors (R5)

| # | Given | When | Then |
| --- | --- | --- | --- |
| E1 | GH1 with ORG and USR; mock: ORG → 404, USR → page with R2 | Both are updated in one run | 102 exists for USR. Error `UpdateFailedErr` with 1 failure naming GH1, `org-a` and the 404 (R5.2, R5.6) |
| E2 | GH1 with ORG, USR (no token: no `/user`); GH2 with OTHER; mock: ORG → 403 with `x-ratelimit-remaining: 0`, `x-ratelimit-reset` = a fixed epoch; OTHER → page with R3 | ORG, USR and OTHER are updated in one run | Requests: ORG's list, then OTHER's list (none for USR). 103 exists. Error lists one rate-limit line for GH1 with 1 skipped owner and the reset time (R5.3) |
| E3 | GH1 with ORG and USR; mock: ORG → 429 with `retry-after: 60` | Both are updated | No request for USR; error has the rate-limit line for GH1 (R5.3) |
| E4 | GH1 with ORG and USR; mock: ORG → 403 without rate-limit headers, USR → page with R2 | Both are updated | USR is requested and 102 exists; error names ORG with 403 (R5.4) |
| E5 | GH1 with ORG and USR; mock: ORG → connection failure, USR → page with R2 | Both are updated | 102 exists; error names ORG (R5.2) |
| E6 | GH1 with ORG and USR; mock: a page for each | Both are updated | Message `UpdatedMsg` with 2; no error (R5.5) |
| E7 | 12 owners on GH1; mock: 404 for each | All are updated | Error lists 10 failures and `MoreFailuresLbl` with 2 (R5.6) |
| E8 | GH1 with ORG (Repository Sync Ignore, 101 stored as `old-name`) and USR (R2) | Both are updated in one run | Only USR is requested; 101 still `old-name`; message `UpdatedWithIgnoredMsg` with 1 and 1 (R1.8, R5.7) |
| E9 | GH1 with ORG set to Ignore | ORG is updated | No request; message `UpdatedWithIgnoredMsg` with 0 and 1 (R5.7) |

## F. Permissions (R6)

| # | Given | When | Then |
| --- | --- | --- | --- |
| F1 | GH1, ORG; mock: R1; exact permission set "Projects User GHP" | ORG is updated | 101 exists (R6.1) |
| F2 | 101 for ORG; "Projects User GHP" | Issue Sync of 101 is set to Ignore and modified | No error (R6.1) |
| F3 | GH1; "Projects User GHP" | An owner is inserted | An error; no owner exists (R6.1) |
| F4 | GH1; "Projects Admin GHP" | An owner is inserted and deleted | Both succeed (R6.2) |
| F5 | 101 for ORG; "Projects User GHP" | 101 is deleted with triggers | No error; 101 no longer exists (R4.7, R6.1) |

## P. Pages (R1.1, R1.7, R2.4, R4.7, R4.8, R5.1) — TestPage

| # | Given | When | Then |
| --- | --- | --- | --- |
| P1 | ORG and USR on GH1; mock: a page for ORG | On "Owners", ORG is the current line and "Update Repositories" is chosen | Only ORG is requested; message `UpdatedMsg` with 1 (R5.1). A TestPage cannot select several lines, so the multi-line selection is checked in M1. |
| P2 | ORG with 101, OTHER with 103 | On "Owners", ORG's "Repositories" action is chosen | The list shows 101 only (R1.7) |
| P3 | 101 for ORG | "Repositories" is opened | Issue Sync is editable; Source Type, Name and Issues Enabled are not. Base URL Code and Owner are hidden (shown through personalization), so the TestPage cannot reach them (R4.7, R4.8) |
| P4 | GH1 with ORG, GH2 with OTHER | On "Base URLs", GH1's "Owners" action is chosen | The list shows ORG only (R2.4) |

## M. Manual checks

Run once before merge, on `tm2023w2v2-nl` (M1, M2) and in an online sandbox (M3). Use a token with read access to repositories (fine-grained: "Metadata: read").

| # | Check | Pass when |
| --- | --- | --- |
| M1 | Base URL `https://api.github.com` without token; owners `microsoft` and `github` (Organization); select both lines and choose "Update Repositories" | Both owners' repositories are listed, with counts above 50 (paging), "Issues Enabled" filled, and the message says 2 owners (R5.1 multi-line selection) |
| M2 | Same base URL with a token of your own account; owner = your login (User); update | Your private repositories are included; removing the token and updating again deletes them |
| M3 | Online sandbox: "Allow HttpClient Requests" on in **Extension Settings** for GithubProjects, off for System Application; update M1's owner | The update works. With the setting off on GithubProjects, it fails with a message that the request was blocked |

## G. Quality gates

- G1 Both apps compile without errors and without warnings under the workspace analyzers and the Bluace ruleset (`bluace-compile.md`).
- G2 All automated tests pass in the AL Test Tool or the AL-Go pipeline (no external communication).
- G3 All user-facing texts are Labels or Captions; en-US and nl-NL translation files are complete in the app and the test app.
- G4 The token never appears in an error, message or request URL, and is never unwrapped.
- G5 No standard object and no other app is modified.
- G6 Section M passed, results recorded in the PR.
- G7 After merge: `specs/tech-design.md`, `specs/roadmap.md` (status `done`), `docs/user-guide.md` and `CHANGELOG.md` are updated.

## Not covered here

- Issues, Issue Sync and Issues Enabled as skip rules, Delete Issues (feature 3).
- Azure DevOps projects (feature 4).
- The job queue and the lock between a manual and a scheduled run (feature 6).
