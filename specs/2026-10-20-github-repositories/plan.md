# Plan — GitHub repositories

Implements [requirements.md](requirements.md) as decided in [tech-design.md §2, §3, §7, §8](../tech-design.md#2-owners-github-only).
App: GithubProjects, a per-tenant extension (ID range 80000–80099, runtime 17.0, application and platform 28.0.0.0; symbols 28.5). Standard objects are not modified.

## Naming and structure

- Every object name ends with ` GHP`; names stay within 30 characters; captions have no suffix (as in feature 1).
- Helper and client codeunits are `Access = Internal` (`bluace-helper-codeunits.md` Rule 2). Pages call table procedures only (`bluace-page-code.md`). Every write passes RunTrigger (`bluace-run-trigger.md`).
- Folders (`bluace-folder-structure.md`):

```
GithubProjects/src/
├── BaseURL/             (existing; Base URL table, page and helper get small additions)
├── GitHub/
│   ├── GitHubClient.Codeunit.al
│   └── HttpClientHandler.Codeunit.al
├── Owner/
│   ├── Owner.Table.al
│   ├── OwnerHelper.Codeunit.al
│   ├── OwnerType.Enum.al
│   ├── Owners.Page.al
│   └── OwnerUpdate.Codeunit.al
├── PermissionSets/      (existing; extended)
└── Repository/
    ├── IssueSync.Enum.al
    ├── Repositories.Page.al
    └── Repository.Table.al
```

- **Deviations from the tech design**, to be written back in the Docs step:
  1. R1.3 and R1.5: owner names are restricted to letters, digits, `-` and `_`, and owners cannot be renamed (proposed 2026-10-20, to be confirmed).
  2. The GitHub client builds absolute URLs from the base URL and does not use `SetBaseAddress`. Rest Client prepends `GetBaseAddress()` to relative URIs as plain text (verified (source): `RestClientImpl.Codeunit.al` `CreateHttpRequestMessage`), and whether the platform adds a trailing `/` to the base address is not documented. Absolute URLs avoid the question; next links from GitHub are absolute anyway.
  3. Every request also sends `X-GitHub-Api-Version: 2022-11-28` (GitHub: "You should use this header", https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api).
  4. Repository has no helper codeunit yet: it has no table procedures in this feature. Feature 3 adds one.
  6. The field for GitHub's `has_issues` is named "Issues Enabled", not "Has Issues", because "Has Issues" read as "the repository has open issues" (decided 2026-10-20).
  5. Issue Sync and Issues Enabled are added now (R4.2, R4.3), so the upsert preserves the user's choice from the first run (decided 2026-10-20). Feature 3 uses them.

## Objects

| Type | ID | Name | Caption | File | Folder |
| --- | --- | --- | --- | --- | --- |
| Enum | 80001 | Owner Type GHP | Owner Type | OwnerType.Enum.al | src/Owner |
| Enum | 80002 | Issue Sync GHP | Issue Sync | IssueSync.Enum.al | src/Repository |
| Table | 80001 | Owner GHP | Owner | Owner.Table.al | src/Owner |
| Table | 80002 | Repository GHP | Repository | Repository.Table.al | src/Repository |
| Page | 80001 | Owners GHP | Owners | Owners.Page.al | src/Owner |
| Page | 80002 | Repositories GHP | Repositories | Repositories.Page.al | src/Repository |
| Codeunit | 80002 | Owner Helper GHP | – | OwnerHelper.Codeunit.al | src/Owner |
| Codeunit | 80003 | Owner Update GHP | – | OwnerUpdate.Codeunit.al | src/Owner |
| Codeunit | 80004 | GitHub Client GHP | – | GitHubClient.Codeunit.al | src/GitHub |
| Codeunit | 80005 | Http Client Handler GHP | – | HttpClientHandler.Codeunit.al | src/GitHub |

Changed existing objects: Table "Base URL GHP" (Source Type trigger, `OnModify`, `OnDelete`), Codeunit "Base URL Helper GHP" (80000), Page "Base URLs GHP" (action Owners), both permission sets.

## Enums (R1.1, R4.7)

- "Owner Type GHP": `Extensible = false` (key decision 13: the endpoint choice is a closed `case`). Values `0 User`, `1 Organization`.
- "Issue Sync GHP": `Extensible = true` (tech design §3). Values `0 Include`, `1 Ignore`. Code only tests `<> Ignore`.

## Table "Owner GHP" (R1)

`DataClassification = CustomerContent`, `Caption = 'Owner'`, `LookupPageId`/`DrillDownPageId` = Page "Owners GHP".

| No. | Name | Type | Properties | Triggers |
| --- | --- | --- | --- | --- |
| 1 | Base URL Code | Code[20] | `NotBlank`; `TableRelation = "Base URL GHP"` | `OnValidate` → `CheckBaseUrl` (R1.2) |

*Changed during implementation (2026-10-20):* the relation has no `Source Type` filter. With the filter, the platform refuses an Azure DevOps base URL with its own "cannot be found in the related table" error before `OnValidate` runs, so the user never sees the GitHub-only explanation (test A2). Turning off `ValidateTableRelation` instead stops renaming a base URL from cascading to its owners (test B4 failed). Without the filter, the lookup also lists Azure DevOps base URLs, and choosing one gives the clear error.
| 2 | Name | Text[100] | `NotBlank` | `OnValidate` → `ValidateName` (R1.3, R1.4) |
| 3 | Owner Type | Enum "Owner Type GHP" | – | – |
| 4 | Repository Sync | Enum "Owner Sync GHP" (80003: `Include`, `Ignore`; `Extensible = false`) | `InitValue = Include` | – (R1.8; added 2026-10-20) |
| 10 | No. of Repositories | Integer | FlowField: `Count("Repository GHP" where("Base URL Code" = field("Base URL Code"), Owner = field(Name)))`; `Editable = false` | – |

Key `PK` (Base URL Code, Name). Triggers: `OnInsert`, `OnModify` → `CheckOwner` (R1.2–R1.4 again, so assigning without validate cannot bypass them); `OnRename` → `Error(OwnerRenameErr)` (R1.5); `OnDelete` → `DeleteRepositories` (R1.6).

Table procedures (each only calls the helper):
- `UpdateRepositories()`: updates the owners in the current filter of `Rec` (R5.1).

## Table "Repository GHP" (R4)

`DataClassification = CustomerContent`, `Caption = 'Repository'`, `LookupPageId`/`DrillDownPageId` = Page "Repositories GHP".

| No. | Name | Type | Properties |
| --- | --- | --- | --- |
| 1 | Base URL Code | Code[20] | `NotBlank`; `TableRelation = "Base URL GHP"` |
| 2 | Id | Code[50] | `NotBlank` (GitHub `id` formatted as text; Azure DevOps GUID in feature 4, tech design §3) |
| 3 | Source Type | Enum "Source Type GHP" | |
| 4 | Owner | Text[100] | `TableRelation = "Owner GHP".Name where("Base URL Code" = field("Base URL Code"))`; blank for Azure DevOps projects |
| 5 | Name | Text[100] | GitHub repository names are at most 100 characters (inferred; stored with `CopyStr` as a safety net) |
| 6 | Issues Enabled | Boolean | |
| 7 | Issue Sync | Enum "Issue Sync GHP" | `InitValue = Include` |

Keys: `PK` (Base URL Code, Id); `OwnerName` (Base URL Code, Owner, Name), used for pruning and as the page sort order.

R2.3: renaming a base URL renames `Base URL Code` in owners and repositories through their `TableRelation`. Verified by test B4 (2026-10-20). It does not run the owner's `OnRename`, so R1.5 does not block it. It does not work when `ValidateTableRelation = false`.

## Codeunit "Owner Helper GHP" (R1, R5)

`Access = Internal`. `Permissions = tabledata "Repository GHP" = rd` (to delete an owner's repositories on owner delete).

- `CheckBaseUrl(var Owner)`: the base URL must exist and have Source Type `GitHub`, else `Error(OwnerNeedsGitHubErr, BaseURLCode)`.
- `ValidateName(var Owner)`: trim (`DelChr(..., '<>', ' ')`); `TestField(Name)`; every character in `A–Z a–z 0–9 - _`, else `Error(InvalidOwnerNameErr, Name)`; `CheckDuplicate`.
- `CheckOwner(var Owner)`: `CheckBaseUrl`, `TestField(Name)`, the character check and `CheckDuplicate`.
- `local CheckDuplicate(var Owner)`: other owners of the same base URL (`SetRange(Base URL Code)`, `SetFilter(Name, '<>%1', Name)`), compared with `LowerCase`; error `DuplicateOwnerErr` (same loop pattern as base URLs: a name with `-` or `_` is safe in a filter, but the loop keeps one pattern).
- `DeleteRepositories(var Owner)`: `Repository.SetRange(Base URL Code, ...)`, `SetRange(Owner, Name)`, `DeleteAll(true)` (tech design §2, confirmed by the customer).
- `UpdateRepositories(var Owner)` (R5): the loop.
  0. Owners with Repository Sync `Ignore` are left out when the caller's selection is copied to a temporary table, and counted; the success message then uses `UpdatedWithIgnoredMsg` (R5.7; added 2026-10-20).
  1. `Owner.FindSet()` on the caller's filter (`SetLoadFields` not used: the whole small record is passed to the runner).
  2. For each owner: if its base URL is in `RateLimitedBaseUrls` (`Dictionary of [Code[20], Text]`), count it as skipped for that base URL and continue (R5.3).
  3. Otherwise `Commit()` and `if not OwnerUpdate.Run(Owner)` → add `StrSubstNo(OwnerFailedLbl, Owner."Base URL Code", Owner.Name, GetLastErrorText())` to `Failures` (`List of [Text]`); then `if OwnerUpdate.GetRateLimitReset(...)` → add the base URL to `RateLimitedBaseUrls` with the reset time. `Commit()` is required before `Codeunit.Run` inside a transaction (verified (Learn): *Codeunit.Run method*, "Transaction semantics").
  4. One `OwnerUpdate` variable is used for the whole run, so its cache of token users per base URL (R3.5) and the rate-limit state survive between owners. Verified (tests C5 and E2, 2026-10-20): a codeunit variable keeps its global variables across `Codeunit.Run` calls, including after a failed run. The GitHub client is a global of "Owner Update GHP"; `Initialize` resets its rate-limit state at the start of each owner.
  5. Each rate-limited base URL adds one failure: `StrSubstNo(RateLimitLbl, BaseURLCode, ResetText, SkippedCount)`.
  6. At the end: no failures → `Message(UpdatedMsg, UpdatedCount)` (R5.5); otherwise `Error(UpdateFailedErr, FailedCount, FailureList)`, listing at most 10 lines plus `MoreFailuresLbl` (R5.6). The text stays well under the 2048 characters of "Job Queue Entry"."Error Message", for feature 6.

## Codeunit "Owner Update GHP" (R3, R4)

`Access = Internal`, `TableNo = "Owner GHP"`. `Permissions = tabledata "Repository GHP" = rimd`.

`OnRun`: `UpdateOwner(Rec)`:
1. Get the base URL; get or create the GitHub client for that base URL (globals: `Dictionary of [Code[20], Text]` for the token user's login; one client per base URL is cheap to create).
2. Pick the endpoint (R3.3–R3.5). For `User` with a token, the login is fetched once per base URL (`GitHubClient.GetTokenUserLogin()`) and cached in the dictionary.
3. `GitHubClient.GetAllPages(Url, Items)` → one `JsonArray` with all pages (R3.6). Any failure raises an error; nothing has been written yet (R4.5, tech design §8 "fetch first, then write").
4. For each item: `Id := Format(id)` (`JsonToken.AsValue().AsBigInteger()`), upsert (R4.1–R4.3); add the Id to `SeenIds: Dictionary of [Code[50], Boolean]`.
5. Prune: repositories with this Base URL Code and Owner (key OwnerName, `SetLoadFields(Id)`) whose Id is not in `SeenIds` → `Delete(true)` (R4.4).
6. `GetRateLimitReset(var ResetText: Text): Boolean`: returns the reset time stored by the client when the last request was rate limited (R5.3); cleared at the start of each `OnRun`.

Upsert: `if Repository.Get(BaseURLCode, Id)` → assign Owner, Name, Issues Enabled and `Modify(true)` only when one changed (Issue Sync is never assigned, R4.2); else `Init`, assign key, Source Type `GitHub`, Owner, Name, Issues Enabled, `Insert(true)` (Issue Sync from `InitValue`).

## Codeunit "GitHub Client GHP" (R3)

`Access = Internal`. One instance per base URL.

- `Initialize(var BaseURL)`: `RestClient := RestClient.Create(HttpClientHandler)`, where the handler is the app's own unless a test supplies one through `OnGetHttpClientHandler` (below). Then:
  - `SetDefaultRequestHeader('Accept', 'application/vnd.github+json')`, `SetDefaultRequestHeader('X-GitHub-Api-Version', '2022-11-28')`;
  - `SetUserAgentHeader(StrSubstNo('%1/%2', ModuleInfo.Name, ModuleInfo.AppVersion))` with `NavApp.GetCurrentModuleInfo` in this app (tech design decision 18). GitHub rejects requests without User-Agent (GitHub docs, getting started);
  - when `BaseURL.HasToken()`: `SetAuthorizationHeader(SecretStrSubstNo('Bearer %1', BaseURL.GetToken()))`.
  - Verified (source and 28.5 symbols): Codeunit 2350 "Rest Client" has `Create(Interface "Http Client Handler")`, `SetDefaultRequestHeader`, `SetUserAgentHeader`, `SetAuthorizationHeader(SecretText)`, `Get`. The default headers are set on the `HttpClient` (`RestClientImpl.Codeunit.al` `SetDefaultRequestHeader`), which the handler receives in `Send`.
- `GetTokenUserLogin(): Text`: `Get(BaseUrl + '/user')`, read `login`.
- `GetAllPages(FirstUrl: Text; var Items: JsonArray)`: first URL + `?per_page=50` (or `&per_page=50`); loop: `Response := RestClient.Get(Url)`; `CheckResponse(Response, Url)`; add the elements of `Response.GetContent().AsJsonArray()` to `Items`; `Url := GetNextLink(Response.GetHeaders())`; until `Url = ''`.
  - `RestClient.Get` raises an error only when no response was received; a 4xx/5xx response is returned with `GetIsSuccessStatusCode() = false` (verified (source): `RestClient.Codeunit.al:206-209`, `RestClientImpl.Codeunit.al` `SendRequest`).
- `local GetNextLink(Headers: HttpHeaders): Text`: if `Headers.Contains('link')`, split the value on `,`; the part that contains `rel="next"` gives the URL between `<` and `>`. Absolute URLs are sent as given (`RestClientImpl` only prepends the base address to URIs that do not start with `http://`/`https://`).
- `local CheckResponse(Response, Url)`: success → exit. Rate limit (status 403 or 429 and `x-ratelimit-remaining = 0`, or a `retry-after` header) → store the reset time (from `x-ratelimit-reset`, epoch seconds UTC, or now + `retry-after` seconds) and `Error(RateLimitErr, BaseURLCode, ResetText)`. Otherwise `Error(RequestFailedErr, Url, StatusCode, ReasonPhrase)`.
- `[InternalEvent(false)] local procedure OnGetHttpClientHandler(var HttpClientHandler: Interface "Http Client Handler"; var IsHandled: Boolean)`: lets the test app supply its mock (`bluace-testing.md` Rule 2). An interface is allowed as an event parameter (`bluace-compile.md` Rule 3).

## Codeunit "Http Client Handler GHP" (R3.1)

`Access = Internal`, `implements "Http Client Handler"`. `Send` calls `CurrHttpClientInstance.Send(HttpRequestMessage.GetHttpRequestMessage(), ResponseMessage)` and wraps the result with `HttpResponseMessage.Create(ResponseMessage)`, as the System Application's Codeunit 2360 does (verified (source): `HttpClientHandler/HttpClientHandler.Codeunit.al:13-18`). Because `HttpClient.Send` runs in this app, "Allow HttpClient Requests" is set on GithubProjects (tech design §7). Manual check M3.

## Base URL changes (R2)

- Field "Source Type" `OnValidate` → `BaseURLHelper.CheckSourceTypeChange(Rec, xRec)`: if the value changed and owners exist → `Error(SourceTypeInUseErr, Code)`.
- `OnModify` (existing `CheckUrl`) also calls `CheckSourceTypeUnchanged(Rec)`: reads the stored record by `SystemId` and refuses a changed Source Type when owners exist, so a `Modify(true)` without validation cannot bypass R2.2.
- `OnDelete` (existing `DeleteToken`) also calls `DeleteOwners(Rec)`: `Owner.SetRange(Base URL Code)`, `DeleteAll(true)`, which deletes the repositories through the owner's `OnDelete` (R2.1).
- Page "Base URLs GHP": action `Owners` (Image `Users`), `RunObject = page "Owners GHP"`, `RunPageLink = "Base URL Code" = field(Code)` (R2.4; `bluace-page-code.md` Rule 2).
- Codeunit "Base URL Helper GHP" `Permissions` add `tabledata "Owner GHP" = rd`.

## Pages (R1.1, R1.7, R4.7, R4.8, R5.1)

- "Owners GHP": `PageType = List`, `UsageCategory = Lists`, `ApplicationArea = All`, `DelayedInsert = true` (lesson from feature 1). Fields: Base URL Code, Name, Owner Type, No. of Repositories (`DrillDownPageId` through the FlowField). Actions:
  - `UpdateRepositories` (Caption 'Update Repositories', Image `Refresh`): `CurrPage.SetSelectionFilter(Owner); Owner.UpdateRepositories(); CurrPage.Update(false);`
  - `Repositories` (Image `List`): `RunObject = page "Repositories GHP"`, `RunPageLink = "Base URL Code" = field("Base URL Code"), Owner = field(Name)`.
- "Repositories GHP": `PageType = List`, `UsageCategory = Lists`, `InsertAllowed = false`, `DeleteAllowed = true` (*changed 2026-10-20*: users may delete lines; a deleted repository comes back on the next update), `SourceTableView = sorting("Base URL Code", Owner, Name)`. All fields `Editable = false` except Issue Sync.

Labels (en-US source; all in the helper or client that raises them):

| Name | Text | Comment |
| --- | --- | --- |
| OwnerNeedsGitHubErr | Owners can only be added to a base URL with Source Type GitHub. Base URL %1 is not a GitHub base URL. | %1 = base URL code |
| InvalidOwnerNameErr | The owner name %1 can only contain letters, digits, hyphens (-) and underscores (_). | %1 = owner name |
| DuplicateOwnerErr | Owner %1 already exists for base URL %2. | %1 = owner name, %2 = base URL code |
| OwnerRenameErr | An owner cannot be renamed. Delete the owner and create a new one. | – |
| SourceTypeInUseErr | You cannot change the Source Type of base URL %1 because it has owners. | %1 = base URL code |
| RequestFailedErr | The request to %1 failed with status %2 %3. | %1 = URL, %2 = HTTP status code, %3 = reason phrase |
| RateLimitErr | GitHub rate limit reached for base URL %1. The limit resets at %2. | %1 = base URL code, %2 = date and time |
| OwnerFailedLbl | %1 %2: %3 | %1 = base URL code, %2 = owner name, %3 = error |
| RateLimitLbl | %1: GitHub rate limit reached; %3 owner(s) skipped. The limit resets at %2. | %1 = base URL code, %2 = date and time, %3 = number of owners |
| UpdatedMsg | The repositories of %1 owner(s) were updated. | %1 = number of owners |
| UpdateFailedErr | The repositories of %1 owner(s) could not be updated:\%2 | %1 = number of failed owners, %2 = list of failures |
| MoreFailuresLbl | ...and %1 more. | %1 = number of further failures |

## Test app (automated tests)

Existing project GithubProjects.Test (50000–50099). No new dependencies. Every UT codeunit has `TestPermissions = Disabled` (`bluace-testing.md` Rule 8).

| Type | ID | Name | File | Folder | Acceptance |
| --- | --- | --- | --- | --- | --- |
| Codeunit | 50006 | UT Owner GHP | UTOwner.Codeunit.al | src/Owner | A |
| Codeunit | 50007 | UT Base URL Owners GHP | UTBaseURLOwners.Codeunit.al | src/BaseURL | B |
| Codeunit | 50008 | UT GitHub Requests GHP | UTGitHubRequests.Codeunit.al | src/GitHub | C |
| Codeunit | 50009 | UT Repository Update GHP | UTRepositoryUpdate.Codeunit.al | src/Repository | D |
| Codeunit | 50010 | UT Update Errors GHP | UTUpdateErrors.Codeunit.al | src/Owner | E |
| Codeunit | 50011 | UT Repository Perm. GHP | UTRepositoryPerm.Codeunit.al | src/Repository | F |
| Codeunit | 50012 | UT Repository UI GHP | UTRepositoryUI.Codeunit.al | src/Repository | P |
| Codeunit | 50013 | Mock Http Handler GHP | MockHttpHandler.Codeunit.al | src/Common | – |
| Codeunit | 50014 | Library - GitHub GHP | LibraryGitHub.Codeunit.al | src/Common | – |

- **Mock** "Mock Http Handler GHP": `implements "Http Client Handler"`, `EventSubscriberInstance = Manual`; it subscribes to `OnGetHttpClientHandler` and supplies itself. Tests call `BindSubscription(MockHttpHandlerGHP)`.
  - Responses are queued per URL (`AddResponse(Url, StatusCode, Body, LinkHeader)`, `AddRateLimitResponse(...)`, `AddConnectionFailure(Url)`). A request to a URL without a queued response fails the test ("unexpected request").
  - It records every request: URL, and whether the client's default headers contain `Authorization`, `Accept`, `X-GitHub-Api-Version` and `User-Agent` (`CurrHttpClientInstance.DefaultRequestHeaders`). Header values that are `SecretText` are only checked for presence.
  - `AssertNoMoreResponses()` after each test proves that every expected request was sent.
  - Response headers: the mock takes the `Headers()` of a local `HttpResponseMessage`, adds `link` and the rate-limit headers with `TryAddWithoutValidation`, and passes them to `SetHeaders` (verified by tests C6, E2 and E3, 2026-10-20).
- **Library** "Library - GitHub GHP": `CreateGitHubBaseURL`, `CreateOwner(var Owner; BaseURL; OwnerType; Name)`, `RepoJson(Id, Name, IssuesEnabled)`, `ReposPage(...)`, `UserJson(Login)`, `CreateRepository(...)`.
- **Backstops**: base URLs on `https://<random>.invalid`; tokens are dummy `SecretText` values (`bluace-testing.md` Rule 2).
- **Permission tests** (F): Permissions Mock with `SetExactPermissionSet` + `AddPermissionSet('Projects Test GHP')`, as in feature 1. "Projects Test GHP" gets X on the new test codeunits and on the mock.
- **Dialogs**: B-, E- and P-tests with messages or questions use handlers. Tests that rely on "no dialog" are confirmed in the AL Test Tool, because the AL MCP runner does not fail on unhandled dialogs (`bluace-testing.md` Rule 1).

## Permission sets (R6)

| Name | Added in this feature | Why |
| --- | --- | --- |
| Projects User GHP | `tabledata "Owner GHP" = R`, `tabledata "Repository GHP" = RiMD`, `table`/`page` X for owners and repositories, `codeunit` X for "Owner Helper GHP", "Owner Update GHP", "GitHub Client GHP", "Http Client Handler GHP" | Users run the update (indirect insert/delete through the update codeunit's `Permissions`) change Issue Sync (direct modify) and delete repository lines (direct delete, decided 2026-10-20). |
| Projects Admin GHP | `tabledata "Owner GHP" = RIMD` | Admins maintain owners. Deleting an owner or base URL deletes repositories through the helpers' indirect permissions. |

## Traceability

| Requirement | Plan section |
| --- | --- |
| R1.1–R1.7 | Owner enum, table, helper, page |
| R2.1–R2.4 | Base URL changes, Repository TableRelation |
| R3.1–R3.7 | GitHub client, Http Client Handler, Owner Update |
| R4.1–R4.8 | Owner Update (upsert, prune), Repository table, Repositories page |
| R5.1–R5.6 | Owner Helper `UpdateRepositories`, Owners page |
| R6.1–R6.2 | Permission sets |
