# Technical Design: GitHub Issues and Azure DevOps Work Items in Business Central

Source: [brief.md](brief.md). Target: application and platform 28.0 (`GithubProjects/app.json`); symbols in `.alpackages` are 28.5.

Evidence conventions:
- **Verified (source)**: read in `external/BCApps` *and* confirmed to exist in the 28.5 symbols in `GithubProjects/.alpackages`.
- **Verified (Learn)**: read on Microsoft Learn. This includes the Azure DevOps REST API reference.
- **Inferred**: a design conclusion, not something read in source or docs.
- GitHub API behaviour is taken from the brief unless a GitHub docs URL is cited. GitHub is not covered by Microsoft Learn.

Paths below are relative to `external/BCApps/src`. The NL layer has no override for any object used here (`Layers/NL/BaseApp` has only `ApplicationArea` and `DataExchange` under `System`), so W1 paths apply.

---

## 1. Settings: multiple base URLs

### What standard BC provides
- **Secret storage**: the platform `IsolatedStorage` data type stores values per key with `DataScope` (default `Module`), and takes `SecretText` values directly, so the token never has to exist as plain `Text` in AL. `Contains` reports whether a key exists. Verified (Learn):
  - https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/methods-auto/isolatedstorage/isolatedstorage-set-string-secrettext-datascope-method
  - https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/methods-auto/isolatedstorage/isolatedstorage-contains-string-datascope-boolean-method
  - `SetEncrypted` limits the input to 215 characters. Fine-grained GitHub PATs can be longer, so plain `Set` with a `SecretText` is the safer choice (inferred; Isolated Storage is already isolated per app).
- **Bearer header (GitHub)**: Codeunit "Rest Client" has `SetAuthorizationHeader(Value: SecretText)`. Verified (source): `System Application/App/Rest Client/src/RestClient.Codeunit.al` line 185.
- **Basic authentication (Azure DevOps)**: Codeunit 2359 "Http Authentication Basic" implements Interface "Http Authentication". `Initialize(Username: Text; Password: SecretText)` builds `Authorization: Basic base64(user:password)` as `SecretText`. Verified (source): `System Application/App/Rest Client/src/Authentication/HttpAuthenticationBasic.Codeunit.al` lines 25 and 58. Rest Client takes it through `Create(HttpClientHandler; HttpAuthentication)` (`RestClient.Codeunit.al` line 51), so the mock handler for tests still fits.
  - Azure DevOps accepts a PAT through basic authentication with an empty user name: base64 of `:{PAT}`. Verified (Learn): https://learn.microsoft.com/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops#use-a-pat
- **Data scope**: `DataScope::Company` keeps a value per company; `DataScope::Module` shares it across all companies. Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/methods-auto/datascope/datascope-option
- **Secret entry dialog**: Codeunit "Password Dialog Management" has `OpenSecretPasswordDialog(DisablePasswordValidation; DisablePasswordConfirmation): SecretText`. It opens Page "Password Dialog" (a `StandardDialog` with `ExtendedDatatype = Masked` fields) and returns the entered value as `SecretText`, without ever showing a stored value. Verified (source): `System Application/App/Password/src/PasswordDialogManagement.Codeunit.al` line 28; `PasswordDialog.Page.al` lines 14–15 and 38–39. Present in the 28.5 symbols.
  - Trade-off: the dialog's captions say "Enter Password" / "Password", not "Token". Accepted: it is the standard secret-entry dialog, and the action caption ("Set Token") tells the user what to enter.
  - A masked **page variable** on the base URL list is not suitable: a global page variable in a repeater shows the same value on every row. The newer `MaskType = Concealed` is not suitable either: it adds a reveal button, is "UI-layer-only" protection ("the unmasked data is transferred to the web browser anyway"), and "isn't allowed in repeater controls". Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/properties/devenv-masktype-property
- **Environment copy**: the platform Codeunit "Environment Triggers" raises `OnAfterCopyEnvironmentPerCompany` in every company after an environment copy. Verified in the System 28.0 symbols; the System Application itself subscribes to it in `System Application/App/Environment Cleanup/src/EnvironmentCleanupImpl.Codeunit.al` line 28. The System Application's own follow-up event `OnClearCompanyConfig` (Codeunit "Environment Cleanup", line 22) is `internal`, so other apps cannot use it; this app subscribes to the platform event directly, as in the example of `bluace-table-triggers.md` Rule 2.
- **Unique secondary key**: a table key with `Unique = true` creates a SQL unique constraint. Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/properties/devenv-unique-property
- **Permission check**: AL has `Record.WritePermission()`. The project rule `bluace-helper-codeunits.md` already prescribes an explicit check for data that table permissions do not protect.

### Gaps
- No standard table holds a list of external API base URLs with a credential each. A new table and page are needed. This is the brief's own deliverable.
- Isolated Storage has no UI and no permission model tied to a table: the write-permission check and the "never read back" behaviour must be coded.

### Implementation decision
- New table "Base URL GHP" with a short surrogate primary key **"Code" (`Code[20]`)**, like standard setup tables, and a list page. Fields:
  - "URL" (`Text[250]`; inferred to be long enough): a normal field with a `Unique = true` secondary key, so the same URL cannot be stored twice. Normalise a trailing `/` on validate, so two spellings of one URL cannot both be stored.
  - "Source Type" (enum "Source Type GHP": `GitHub`, `Azure DevOps`; `Extensible = false`, because each value needs its own API client).
- Every child table (owner, repository, issue) refers to the base URL by "Base URL Code" (`Code[20]`), not by the URL. Changing the URL (for example when a GitHub Enterprise host moves) is then a single-field update; no key of an owner, repository or issue row changes.
- Source Type cannot be changed once owners or repositories exist for the base URL. Inferred: otherwise stored GitHub data would sit under an Azure DevOps URL.
- The token key in Isolated Storage is derived from the record's `SystemId`. Deleting the record deletes the token (table `OnDelete` → helper).
- Tokens are stored with **`DataScope::Company`**, so each company keeps its own token and deleting a base URL in one company cannot delete a token another company uses.
- **Token entry**: the list page has actions "Set Token" and "Clear Token" (no token field or page variable). "Set Token" calls `Rec.SetToken()`; the helper checks `WritePermission()` on the base URL table, calls "Password Dialog Management".`OpenSecretPasswordDialog(true, true)` (no password-strength validation, no confirmation field), and writes the returned `SecretText` with `IsolatedStorage.Set(Key, Token, DataScope::Company)`. An empty result (dialog cancelled) changes nothing. "Clear Token" asks "Confirm Management" and deletes the key. A read-only Boolean "Token Set" (computed through `IsolatedStorage.Contains`) shows whether a token exists. The token can never be read back in the UI.
- **Environment copy**: codeunit "Env. Trigger Subscr. GHP" (folder `src/General/`) subscribes to Codeunit "Environment Triggers" `OnAfterCopyEnvironmentPerCompany` and deletes the tokens of all base URLs in that company. A copy of production into a sandbox then never carries live tokens. It runs on every environment copy, whatever the destination type; the user sets the tokens again in the copy.
- Authentication per source type:
  - `GitHub`: when a token exists, `SetAuthorizationHeader` with `Bearer <token>` (built with `SecretStrSubstNo`, per `bluace-compile.md` Rule 3). Without a token, no header is sent and only public data is returned.
  - `Azure DevOps`: Rest Client is created with Codeunit "Http Authentication Basic", initialised with an empty user name and the token. Without a token, the update stops for that base URL with a clear error (collected, section 7).

---

## 2. Owners (GitHub only)

### What standard BC provides
- Nothing GitHub-specific. Standard BC does give the building blocks: an enum field for Owner Type, a composite primary key (base URL + owner), and a `TableRelation` to the base URL table, filtered on `"Source Type" = const(GitHub)`.
- Case-insensitive comparison of the token user's `login` with the owner is plain AL (`LowerCase` on both sides). No library is needed.

### Gaps
- Owner table, enum "Owner Type" (`User`, `Organization`) and page are new (brief deliverable).
- Choosing an endpoint by owner type and by "is this the token's user" is custom logic.

### Implementation decision
- New table "Owner GHP" with key (Base URL Code, Owner), field "Owner Type" (enum "Owner Type GHP", `Extensible = false`: the endpoint choice is a closed `case`), and a list page. The base URL relation only allows `GitHub` base URLs.
- The helper picks the endpoint:
  - `Organization` → `/orgs/{owner}/repos`.
  - `User` → if a token is set, call `GET /user` once per base URL per run and cache its `login`. If it equals the owner (case-insensitive), use `/user/repos?affiliation=owner&visibility=all`; otherwise use `/users/{owner}/repos`. Without a token, skip `/user` and use `/users/{owner}/repos` directly.
- Deleting an owner deletes its repositories (and so their issues) through the table `OnDelete` trigger, with `DeleteAll(true)`. Confirmed by the customer (2026-10-20).

---

## 3. Repositories and projects

### What standard BC provides
- **Extensible enum**: `Extensible = true` on an enum lets other apps add values with an `enumextension`. The default for enums is `false`, so it must be set explicitly. Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/devenv-extensible-enums and https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/properties/devenv-extensible-property
- **Confirmation dialog**: Codeunit "Confirm Management" (`GetResponseOrDefault`, `GetResponse`) in the System Application. Verified (source): `System Application/App/Confirm Management/src/ConfirmManagement.Codeunit.al` lines 27–62. Also present in the 28.5 symbols.
- **Bulk delete**: `DeleteAll(true)` on a filtered issue record. Platform.
- **Azure DevOps project list**: `GET https://dev.azure.com/{organization}/_apis/projects?api-version=7.1` returns the projects the authenticated user can access. Each project has an `id` (uuid) and a `name`. The list supports the query parameters `$top` and `$skip` (and `continuationToken`, documented only as an int32 "pointer that shows how many projects already been fetched"). Verified (Learn): https://learn.microsoft.com/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-7.1
- **GitHub `has_issues`**: the repository objects returned by the repository list endpoints include `has_issues` (boolean) and `fork` (boolean). Source: https://docs.github.com/en/rest/repos/repos#list-organization-repositories

### Gaps
- Repository table, enum "Issue Sync" and list page are new (brief deliverable).
- Preserving the user's Issue Sync choice during upsert is custom logic (see section 8).

### Implementation decision
- One table "Repository GHP" for GitHub repositories **and** Azure DevOps projects. The same Issue Sync option, Delete Issues action and Update Issues action apply to both, so a second table would only duplicate them.
  - Key (Base URL Code, Id), with `Id` as `Code[50]`. It holds the GitHub repository id (an integer, formatted as text) or the Azure DevOps project id (a GUID). `Code` makes the match independent of the case in which the API returns the GUID.
  - Fields: Source Type (from the base URL), Owner (GitHub only; blank for projects), Name, "Has Issues" (Boolean; GitHub's `has_issues`, always true for Azure DevOps projects), and Issue Sync with `InitValue = Include`.
- **GitHub repositories with issues turned off** (`has_issues = false`, the default for forks) are skipped when issues are retrieved, the same way as `Ignore`: no request is sent, it is not a failure, and issues already stored for the repository are kept. The repository list shows "Has Issues" so the user can see why a repository gets no issues.
- Enum "Issue Sync GHP" with `Extensible = true`. Code only ever tests `<> Ignore`. It never uses `case` with an `else` error or range comparisons, so extension values behave like `Include` until their own logic is added. Inferred: a later extension may want its own behaviour. If so, add an integration event at the "should issues be retrieved for this record" decision point. That is cheap and fits `al-events.md`.
- The upsert updates only source fields (name, owner, …) and never assigns Issue Sync on modify.
- Action "Delete Issues" on the repository list: `CurrPage.SetSelectionFilter` → table procedure → helper asks "Confirm Management" and then deletes the issues of the selected records with `DeleteAll(true)`.
- Deleting a repository or project deletes its issues/work items via the table `OnDelete` trigger.
- Projects are retrieved per Azure DevOps base URL (there is no owner level), with the documented `$top`/`$skip` parameters: `$top=100`, `$skip` increased by 100 per request, until a page returns no projects. This needs no response headers, so `GetAsJson` is enough. The reference does not document a short page as the last page, so the loop stops only on an empty page, at the cost of one extra request.

---

## 4. GitHub issues

### What standard BC provides
- JSON parsing with the platform `JsonObject`/`JsonArray`/`JsonToken` types. Codeunit "Http Content" has `AsJsonArray()` to read a response body. Verified (source): `System Application/App/Rest Client/src/HttpContent.Codeunit.al` line 254.

### Gaps
- Skipping pull requests (items with a `pull_request` property) and mapping `state` are custom parsing.

### Implementation decision
- Parsing: skip any item where `Contains('pull_request')` is true. Map `open`/`closed` to enum "Issue State GHP". An unknown state value is an error for that repository: it is collected as a failure (section 7) instead of being stored silently wrong.
- Issues are written to the shared table (section 6) with Type `Issue`, Parent Id 0, Number = the GitHub `number`.

---

## 5. Azure DevOps user stories and tasks

### What standard BC provides
- Nothing in BC: this is new integration logic. The Azure DevOps APIs used are documented:
  - **WIQL**: `POST {organization}/{project}/_apis/wit/wiql?api-version=7.1` with `{"query": "..."}` returns only work item ids (`workItems[].id`), whatever is selected. Verified (Learn): https://learn.microsoft.com/rest/api/azure/devops/wit/wiql/query-by-wiql?view=azure-devops-rest-7.1 and https://learn.microsoft.com/azure/devops/boards/queries/wiql-syntax?view=azure-devops
  - **Work items batch**: `POST {organization}/{project}/_apis/wit/workitemsbatch?api-version=7.1` with `ids` (maximum 200), `fields` and `errorPolicy` (`fail` or `omit`). The sample response leaves out fields that have no value. Verified (Learn): https://learn.microsoft.com/rest/api/azure/devops/wit/work-items/get-work-items-batch?view=azure-devops-rest-7.1
  - **Parent**: field `System.Parent` holds the parent work item's id as an Integer. It can be requested as a field, so no relation expansion is needed. Verified (Learn): https://learn.microsoft.com/azure/devops/boards/queries/linking-attachments?view=azure-devops#fields-associated-with-links-and-attachments
  - **State categories**: `GET {organization}/{project}/_apis/wit/workitemtypes/{type}/states?api-version=7.1` returns each state's `category` (`Proposed`, `InProgress`, `Resolved`, `Completed`, `Removed`). Verified (Learn): https://learn.microsoft.com/rest/api/azure/devops/wit/work-item-type-states/list?view=azure-devops-rest-7.1 and https://learn.microsoft.com/azure/devops/boards/work-items/workflow-and-state-categories?view=azure-devops
  - **Title**: up to 255 characters, so `Text[256]` always fits. Verified (Learn): https://learn.microsoft.com/azure/devops/boards/work-items/about-work-items?view=azure-devops#work-item-form-and-details-tab
- **Rest Client** has `PostAsJson(RequestUri; Content: JsonObject)`, which returns the response as a `JsonToken` and errors on a non-success status. Verified (source): `RestClient.Codeunit.al` line 276. No response headers are needed for WIQL or the batch call, so `PostAsJson` fits.
- **Limit**: a WIQL query is reported to fail when it matches more than 20,000 work items. This comes from a Microsoft Q&A answer, not from the API reference (https://learn.microsoft.com/answers/a/12251493), so treat it as likely, not verified.

### Gaps
- The two-step retrieval (ids, then batches), the state mapping and the parent link are custom.

### Implementation decision
- Per project (Issue Sync not `Ignore`):
  1. WIQL: `Select [System.Id] From WorkItems Where [System.TeamProject] = @project And [System.WorkItemType] In ('User Story', 'Task') Order By [System.Id]`.
  2. Batches of up to 200 ids to `workitemsbatch` with fields `System.Id`, `System.Title`, `System.State`, `System.WorkItemType`, `System.Parent`, and **`"errorPolicy": "omit"`**. With the default (`fail`), one work item deleted between the WIQL call and the batch call would fail the whole batch, and so the whole project for that run. With `omit`, such an item comes back as an empty entry and is skipped; it is then deleted from BC like any item that is no longer returned. A missing `System.Parent` key means no parent (Parent Id 0).
  3. State categories: for `User Story` and `Task`, call the states endpoint once per project per run and cache name → category. `Completed` and `Removed` map to `Closed`; every other category maps to `Open`. A state missing from the cache is an error for that project (collected), not a silent `Open`.
- If the WIQL call fails (including the reported 20,000 limit), the project fails as a whole and nothing is deleted (section 8).
- Pull requests are excluded without extra code: in Azure DevOps they belong to Azure Repos (Git) and are not work items, so a WIQL query on `[System.WorkItemType] In ('User Story', 'Task')` cannot return them. No Azure Repos endpoint is called. Inferred from the WIQL reference, which queries only `WorkItems`.
- Type names are those of the Agile process, as the brief states. Inferred: a project on another process returns only tasks, or nothing. This is a known limitation, not an error.

---

## 6. The shared Issue table

### What standard BC provides
- **Collapsible tree on a list page**: repeater properties `IndentationColumn` (an Integer field), `ShowAsTree = true` and optional `TreeInitialState`. Rows must be sorted so that each child follows its parent. Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/devenv-indented-hierarchy-lists and https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/properties/devenv-showastree-property
  - Trade-offs from the same pages: with indentation, users can no longer sort on columns, and more than 1,000 nested rows under one root row can be slow. User stories rarely have that many tasks (inferred).
- **Parent description without code**: a `FlowField` with `CalcFormula = lookup(...)` on the same table. Platform feature.

### Gaps
- BC has no issue tracker table to reuse. Inferred: I looked for a generic "external work item" table in the Base App and found none.
- The tree needs two derived fields (root id, indentation) that the APIs do not return.

### Implementation decision
- New table "Issue GHP", keyed by (Base URL Code, Id) with `Id` as `BigInteger`. GitHub issue ids are global per host; Azure DevOps work item ids are unique per organization. Both are unique within one base URL. Fields:
  - Source Type (enum "Source Type GHP", from the base URL), Repository Id (`Code[50]`, relation to "Repository GHP" on Base URL Code + Id), Number (`Integer`), Type (enum "Issue Type GHP": `Issue`, `User Story`, `Task`; `Extensible = false`), Description (`Text[256]`), State (enum "Issue State GHP": `Open`, `Closed`; `Extensible = false`), Parent Id (`BigInteger`, 0 = none).
  - Parent Description: FlowField lookup of Description on (Base URL Code, Parent Id).
  - Tree fields, filled by the helper: Tree Root Id (`BigInteger`) and Indentation (`Integer`). A task whose parent is a stored user story of the same project gets root = Parent Id and indentation 1. Every other record gets root = its own Id and indentation 0.
  - A key (Base URL Code, Repository Id, Tree Root Id, Indentation, Id), used as the page's sort order, so each user story is followed by its tasks.
- The tree fields are computed after all work items of a project are upserted, in a second pass over that project. A parent can arrive in a later batch than its child, so they cannot be set during the upsert.
- Description is `Text[256]`, as confirmed by the customer, and stored with `CopyStr(..., 1, MaxStrLen(...))` as a safety net for both sources.
- Issue list page: `ShowAsTree = true` on `Indentation`. Columns: Source Type, Type, Number, Description, State, Parent Id, Parent Description. GitHub issues are always top-level rows.

---

## 7. Data retrieval with the Rest Client

### What standard BC provides
- **Codeunit "Rest Client"** (System Application): `Create`/`Initialize`, `SetBaseAddress`, `SetDefaultRequestHeader`, `SetAuthorizationHeader`, `Get`, `GetAsJson`, `PostAsJson`. Verified (source): `System Application/App/Rest Client/src/RestClient.Codeunit.al`. Present in the 28.5 symbols.
  - It sets a default `User-Agent` (`RestClientImpl.Codeunit.al` lines 24 and 74), built from `NavApp.GetCurrentModuleInfo` inside Rest Client Impl, so it names the **System Application**, not GithubProjects. `SetUserAgentHeader(Value: Text)` replaces it. Verified (source): `RestClient.Codeunit.al` line 176; present in the 28.5 symbols.
  - `GetAsJson` returns only the body and raises a collectible error on a non-success status (`RestClientImpl.Codeunit.al` lines 155–165). It **does not expose response headers**.
  - `Get` returns Codeunit "Http Response Message" with `GetHeaders()`, `GetIsSuccessStatusCode()`, `GetHttpStatusCode()` and `GetContent()`. Verified (source): `HttpResponseMessage.Codeunit.al`.
  - **Where the request is sent**: Rest Client does not call `HttpClient.Send` itself. It passes the request to an Interface "Http Client Handler" (`RestClientImpl.Codeunit.al` line 293). Without a handler, `Create()`/`Initialize()` use the default Codeunit 2360 "Http Client Handler" of the **System Application**, whose `Send` makes the actual `HttpClient.Send` call (`HttpClientHandler/HttpClientHandler.Codeunit.al` line 17; defaults at `RestClientImpl.Codeunit.al` lines 14, 30, 53). Verified (source).
  - `Create(HttpClientHandler: Interface "Http Client Handler")` and `Create(HttpClientHandler; HttpAuthentication)` take a handler from the caller. Verified (source): `RestClient.Codeunit.al` lines 31 and 51; interface `HttpClientHandler/HttpClientHandler.Interface.al`. The same overloads let tests pass a mock, per `bluace-testing.md` Rule 2.
- **Allow HttpClient Requests**: outbound HTTP calls are blocked in sandboxes until this extension setting is enabled, and it "must be enabled for each app/extension, including library apps". Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/methods-auto/httpclient/httpclient-data-type#ways-that-httpclient-calls-can-fail
  - Learn does not state in so many words which app's setting is checked. Inferred: it is the app whose code calls `HttpClient.Send`. With the default handler, that is the System Application, so the System Application's setting would decide, and enabling it would open HTTP for every app that uses Rest Client. **Verify in a sandbox during implementation**: with the app's own handler, enabling the setting on GithubProjects alone must be enough.
- **No paging support** in Rest Client: no `Link` header or continuation-token handling exists in `RestClientImpl.Codeunit.al` (verified by search; a failed search does not prove absence elsewhere, but nothing in the module's public API offers it).
- **GitHub paging** works through the `link` response header: follow `rel="next"` until it is absent. GitHub does **not** document a short page as the last page, and it may silently lower `per_page`. Source: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api
- **GitHub rate limits**: 60 requests per hour per IP address without a token; 5,000 per hour with a personal access token. An exceeded limit returns **403 or 429**; for the primary limit `x-ratelimit-remaining` is `0` and `x-ratelimit-reset` gives the reset time (UTC epoch seconds); secondary limits may send `retry-after` (seconds). GitHub says not to keep sending requests while rate limited, and warns that doing so may get the integration banned. Source: https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
- **Job Queue**: Table "Job Queue Entry" has `FindJobQueueEntry(ObjType; ObjID)` and scheduling procedures. Page 673 "Job Queue Entry Card" is the standard card. Verified (source): `Layers/W1/BaseApp/Modules/System/JobQueue/JobQueueEntry.Table.al` lines 1328–1440, `JobQueueEntryCard.Page.al`. A new entry starts as **On Hold**, so the user sets the schedule and then chooses Set Status to Ready. Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/admin-job-queues-schedule-tasks
- **Job Queue error logging**: when the codeunit errors, Codeunit "Job Queue Error Handler" sets status Error and stores the last error in "Job Queue Entry"."Error Message" (`Text[2048]`) and in the Job Queue Log Entry through Error Message Management. Verified (source): `JobQueueErrorHandler.Codeunit.al` lines 11–60, `JobQueueEntry.Table.al` line 327. Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/devenv-job-queue#how-job-queue-works
  - So "end with an error that names the failures" needs **no custom logging**: raise one final `Error` with the collected failures. Keep it under 2048 characters (e.g. list the first N and a count).
  - Background sessions cannot show `Confirm`; the job codeunit must not reach any dialog. Verified (Learn): same page, section "Running codeunits with the job queue".
- **Error isolation per unit of work**: `if Codeunit.Run(...) then` catches the error and commits that unit's changes; "if you're already in a transaction you must commit first". Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/methods-auto/codeunit/codeunit-run-method
  - Try functions are not suitable: they do not roll back, and on-premises they block database writes by default. Verified (Learn): https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/devenv-handling-errors-using-try-methods
- **Concurrency**: Job Queue **Category** serialises job queue entries in the same category (status `Waiting`). Verified (Learn): admin-job-queues-schedule-tasks, status table. This does **not** cover a manual run in a user session. I found no standard named lock or mutex in the Base App or System Application for "one process at a time across sessions". The platform table "Active Session" exists (verified in the System 28.0 symbols) and can tell whether a session is still alive.

### Gaps
- Paging over the GitHub `link` header must be coded on top of `Rest Client.Get`; Azure DevOps project paging (`$top`/`$skip`) is a simple loop.
- Rate-limit detection for GitHub is custom.
- The "process every unit, collect failures, fail at the end" loop is custom.
- The guard against a manual and a scheduled run at the same time is custom.

### Implementation decision
- **The app's own Http Client Handler**: a codeunit "Http Client Handler GHP" in this app implements Interface "Http Client Handler", and its `Send` calls `HttpClient.Send`. Rest Client is **always** created with this handler (`Create(Handler)` or `Create(Handler; Authentication)`), never with the parameterless `Create()`/`Initialize()`. So the outbound call runs in GithubProjects' code, and **Allow HttpClient Requests** is enabled on GithubProjects in Extension Management, not on the System Application.
  - Tests replace this handler with the mock through an `[InternalEvent]` (`bluace-testing.md` Rule 2). If no subscriber supplies a mock, the app's own handler is used.
- **One API client per source type** (internal codeunits). Both wrap Rest Client, created with the handler above, and both call `SetUserAgentHeader` with this app's own name and version (`NavApp.GetCurrentModuleInfo` in GithubProjects, e.g. `GithubProjects/1.24.0.0`), so requests identify GithubProjects instead of the System Application.
  - GitHub client: base address, `Accept: application/vnd.github+json`, bearer token if present. "Get all items of a list endpoint" returns one `JsonArray` with all pages. The first request adds `per_page=50`. Each response is read with `Get`; a non-success status raises an error with status code and reason phrase. The `link` header's `rel="next"` URL is followed as-is until there is no next link.
  - **GitHub rate limits**: a 403 or 429 response with `x-ratelimit-remaining` = 0 or a `retry-after` header is recognised as a rate limit, not as an ordinary failure. The client raises a distinct "rate limit reached for {base URL}, resets at {time}" error. The update codeunit then skips all remaining owners and repositories of **that base URL** for this run (one collected failure instead of one per unit) and continues with the other base URLs. No request is retried within the run, as GitHub asks. A plain 403 without these headers stays an ordinary failure (for example missing access).
    - Without a token the limit is 60 requests per hour per IP address, which a few owners with several pages each can exceed. The settings page shows this next to "Token Set" (a tooltip on the base URL list), and the user guide recommends a token for every GitHub base URL.
  - Azure DevOps client: base address, basic authentication (section 1), `api-version=7.1` on every request. Project list through `GetAsJson` with `$top`/`$skip` (section 3); WIQL and batches through `PostAsJson`; state categories through `GetAsJson`.
- **One update codeunit** holds the shared logic, used by both entry points. Units of work, each in its own `Codeunit.Run` after a `Commit`:
  - GitHub owner (repositories ± issues), GitHub repository (issues);
  - Azure DevOps base URL (projects ± work items), Azure DevOps project (work items).
  - A failure is added to a list of texts (unit + `GetLastErrorText()`), and the loop continues. At the end, if the list is not empty: in the job queue, `Error` with the summary (logged by standard JQ). In a manual run, the same summary is shown as an error, so the user sees it.
- **Job queue codeunit**: a thin codeunit whose `OnRun` calls "update everything": all GitHub base URLs → owners → repositories → issues, and all Azure DevOps base URLs → projects → work items, skipping `Ignore`. No parameter string.
- **Settings page action "Create Job Queue Entry"**: table procedure → helper. It uses `FindJobQueueEntry(Codeunit, <id>)`; if no entry exists, it inserts one (On Hold, recurring, description from the codeunit caption). It then opens Page "Job Queue Entry Card" on it. The scheduling helpers `ScheduleRecurrentJobQueueEntry*` are **not** used: they enqueue immediately (status Ready) with fixed defaults (08:00, 3 attempts), but the brief wants the user to set the schedule.
- **Manual actions**: owner list "Update Repositories" and "Update Repositories and Issues"; settings list "Update Projects" and "Update Projects and Work Items" (enabled for Azure DevOps base URLs); repository list "Update Issues" (repositories and projects). Each passes the selection to a table procedure.
- **Concurrency guard** (inferred design; no standard equivalent found): one small single-record "update lock" holding Session ID, Server Instance ID and start time. Each run (manual or scheduled) does the following:
  - At the start it reads the lock with `LockTable`. If the lock is held by a session that is still in "Active Session", the run stops with a clear message naming who and since when. Otherwise it claims the lock and commits.
  - It clears the lock at the end, also after collected failures.
  - A stale lock left by a crashed session is ignored automatically, because that session is no longer active.
  - Scope is global (one update at a time, for both sources). That is simpler than per base URL and enough for the expected volumes. Revisit if runs become long.
  - "Waits" from the brief is not implemented: stopping with a message is simpler and allowed by the brief. A job queue run that hits the lock fails and is retried by standard JQ (Maximum No. of Attempts / Rerun Delay).

---

## 8. Repeated retrieval (upsert and removal)

### What standard BC provides
- AL has no upsert statement. The standard pattern is `Get` → `Modify(true)`, else `Init` + `Insert(true)`. Platform.
- `List of [...]` or `Dictionary` for the set of ids seen in a run. Platform. This matches `al-performance.md` Rule 3.
- Transaction rollback on error inside `Codeunit.Run` (see section 7). This gives "nothing is deleted if a request fails halfway" without extra state.

### Gaps
- The upsert-and-remove logic per owner, base URL, repository and project is custom.

### Implementation decision
- Order of work per unit: **first** retrieve everything into memory (all pages, or the WIQL ids plus all batches). Only when every request succeeded, upsert each item by (Base URL Code, Id) and delete the stored records of that scope whose id was not seen:
  - repositories of the owner (GitHub); projects of the base URL (Azure DevOps);
  - issues of the repository; work items of the project. A work item whose type changed away from User Story or Task is no longer returned by the WIQL query, so it is deleted.
- `OnDelete` cascades remove the children of deleted repositories and projects.
- Because all HTTP calls finish before the first write, a failure during retrieval leaves the database untouched. Because each unit runs in its own `Codeunit.Run`, a failure while writing rolls back only that unit.
- Records are matched by id within the base URL, so a renamed repository or project is updated, not duplicated.
- Known edge cases (inferred):
  - A GitHub repository transferred between two owners that are both tracked can be deleted under the old owner and then reinserted under the new one. It then loses its stored issues until the next issue sync, and its Issue Sync choice falls back to `Include`. Accept and document.
  - An Azure DevOps work item moved to another project is deleted from the old project and inserted under the new one in the same run or the next. Its key (Base URL Code, Id) does not change, so the upsert of the new project updates its Repository Id. Order of processing decides whether it disappears for one run. Accept and document.
- Writes pass `RunTrigger` explicitly (`bluace-run-trigger.md`). Upserts use `true`.

---

## Cross-cutting

- **Naming**: every object carries the app suffix `GHP` (`GithubProjects/AppSourceCop.json`). Working names: Tables "Base URL GHP", "Owner GHP", "Repository GHP", "Issue GHP"; enums "Source Type GHP", "Owner Type GHP", "Issue Sync GHP", "Issue Type GHP", "Issue State GHP". Names must stay within 30 characters including the suffix.
- **Permissions**: one permission set for users (read on all tables, run the update) and one for admins (write on the base URL table, which also controls who can set the token). The job queue runs as the user who set the entry to Ready (Learn: devenv-job-queue, "About job queue sessions and permissions"), so that user needs the user set.
- **Data classification**: the token is never in a table. The other fields are `CustomerContent`.
- **No upgrade code** is needed: this is the first version of all tables.
- **Telemetry**: none unless requested (`al-error-handling.md` Rule 4).

---

## Key design decisions

1. The token is stored in Isolated Storage (`DataScope::Company`, `SecretText`) under a key derived from the base URL record's `SystemId`, entered through the standard "Password Dialog Management" dialog, and written only after an explicit `WritePermission()` check. It is never shown or read back.
2. Neither a masked page variable on the list (same value on every row) nor `MaskType = Concealed` (reveal button, sent to the browser, not allowed in repeaters) is used for the token.
3. A Source Type enum on the base URL selects the API client: GitHub uses a bearer token; Azure DevOps uses the standard Codeunit "Http Authentication Basic" with an empty user name.
4. All HTTP goes through Codeunit "Rest Client", always created with the app's own "Http Client Handler GHP", so `HttpClient.Send` runs in this app and "Allow HttpClient Requests" is enabled on GithubProjects, not on the System Application. Tests swap the handler for a mock. List calls use `Get` (not `GetAsJson`) where response headers are needed for paging.
5. GitHub paging follows the `link: rel="next"` header and does not count items, because GitHub documents that `per_page` can be lowered silently. Azure DevOps uses a WIQL query for ids and batches of at most 200 work items.
6. GitHub repositories and Azure DevOps projects share one Repository table (key Base URL Code + `Code[50]` Id), and issues and work items share one Issue table with Source Type, Type and Parent Id.
7. User stories and their tasks are shown with the standard collapsible tree (`ShowAsTree`), using a stored root id and indentation computed after each project's upsert, plus a FlowField for the parent's description.
8. Azure DevOps states map to Open/Closed through their state category (`Completed`/`Removed` → Closed), so custom state names work without configuration.
9. Every unit of work (owner, base URL, repository, project) runs in its own `Codeunit.Run`, so one failure is isolated and rolled back. Failures are collected and raised as one final error that standard Job Queue error handling logs.
10. Everything for a unit is fetched before any write, so removal only happens after a complete, successful retrieval.
11. The scheduled entry is created On Hold through a helper that inserts a "Job Queue Entry" and opens the standard "Job Queue Entry Card". The standard `ScheduleRecurrent*` helpers are not used because they enqueue immediately with fixed defaults.
12. Manual and scheduled runs share one global session-based lock, checked against "Active Session", because BC has no standard cross-session mutex. A conflicting run stops with a message instead of waiting.
13. Issue Sync is an extensible enum and code tests only `<> Ignore`. Source Type, Owner Type, Issue Type and Issue State are closed enums.
14. Upserts never touch Issue Sync, and deletes cascade through table `OnDelete` triggers (base URL → owners → repositories/projects → issues/work items). Deleting an owner cascades (confirmed by the customer).
15. Titles are stored in `Text[256]` (confirmed by the customer; Azure DevOps titles are at most 255 characters) with `CopyStr` as a safety net.
16. Base URLs have a surrogate `Code[20]` primary key; the URL is a normal field with a unique secondary key, and child tables refer to the code, so changing a URL rewrites no keys.
17. Tokens are deleted after every environment copy through a subscriber on the platform event "Environment Triggers".`OnAfterCopyEnvironmentPerCompany`, so production tokens never reach a sandbox.
18. Both API clients send this app's own User-Agent through `SetUserAgentHeader`, instead of Rest Client's default, which names the System Application.
19. A GitHub rate-limit response (403/429 with `x-ratelimit-remaining` = 0 or `retry-after`) stops that base URL for the current run with one collected failure; nothing is retried within the run.
20. GitHub repositories with `has_issues = false` are skipped like `Ignore`, not counted as failures; Azure DevOps batches use `errorPolicy: omit`, and projects are paged with `$top`/`$skip` until an empty page.
