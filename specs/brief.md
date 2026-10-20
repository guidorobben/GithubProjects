# Brief: GitHub Issues and Azure DevOps Work Items in Business Central

## Goal

Retrieve repositories and their issues from GitHub, and tasks from Azure DevOps, and store them in Business Central, so they can be viewed and used there.

From Azure DevOps, the app retrieves **user stories and tasks**, per project, and stores them so the user can see which tasks are children of which user story.

## Scope

Pull requests are out of scope for both sources: they are never stored (see sections 4 and 5).

### 1. Settings: multiple base URLs

- A settings table and page where the user maintains **multiple base URLs** (one record per URL).
- Each base URL has a **Source Type** (enum): `GitHub` or `Azure DevOps`. It decides which API is called and how the token is sent.
- Examples:
  - `GitHub`: `https://api.github.com` (github.com) and `https://<host>/api/v3` (GitHub Enterprise Server).
  - `Azure DevOps`: `https://dev.azure.com/{organization}` (Azure DevOps Services). Azure DevOps Server (on-premises) is out of scope.
- Each base URL has its own **token** (personal access token).
  - The token is kept in **Isolated Storage**, not in a table field.
  - `GitHub`: sent as a bearer token in the `Authorization` header. The token gives access to private repositories and higher rate limits. Without a token, the base URL can only be used for public data.
  - `Azure DevOps`: sent with basic authentication (empty user name, the token as password). A token is required. It needs the scopes to read projects and work items.
  - The page shows a masked input field only; the token value can never be read back in the UI.
  - Setting or clearing the token requires write permission on the settings table, checked explicitly in the helper codeunit.

### 2. Owners (GitHub only)

- A table and page where the user stores the GitHub **owners** to retrieve data for.
- Every owner belongs to one base URL of source type `GitHub`. The key is base URL + owner, so the same owner name can be used on different base URLs.
- Each owner has an **Owner Type** (enum): `User` or `Organization`. It decides which endpoint lists the repositories:
  - `User`: `GET {base URL}/users/{owner}/repos` returns public repositories only, also with a token. When the owner is the **user the token belongs to**, the app uses `GET {base URL}/user/repos?affiliation=owner&visibility=all` instead, so that user's **private repositories** are retrieved too. The app finds the token's user with `GET {base URL}/user` (field `login`, compared case-insensitively with the owner).
  - `Organization`: `GET {base URL}/orgs/{owner}/repos` returns the public repositories, plus the private ones the token can access.
- Deleting an owner deletes its repositories, together with their issues.
- Consequence for removal (see section 7): when the token is removed or replaced by one with less access, private repositories are no longer returned and are deleted on the next retrieval, together with their issues.

### 3. Repositories and projects

- One **Repository** table, with a list page, holds both GitHub repositories and Azure DevOps projects. Each record has the **Source Type** of its base URL.
  - `GitHub`: from an owner, the app retrieves that owner's repositories. Each repository records its base URL and owner.
  - `Azure DevOps`: from a base URL (organization), the app retrieves all projects the token can access, with `GET {base URL}/_apis/projects`. Each project records its base URL; it has no owner.
- Each record has an **Issue Sync** option, an **extensible enum**, which controls whether issues or work items are retrieved for it:
  - `Include`: issues or work items are retrieved (default for new records)
  - `Ignore`: this repository or project is skipped
  - Later values can be added through an enum extension, so code must not assume these are the only two.
- The user can change the option on the repository page. Retrieving repositories or projects again does **not** overwrite it.
- Setting a record to `Ignore` **keeps** the issues or work items already stored for it. The repository page has an action **Delete Issues** that deletes the stored issues or work items of the selected records, after a confirmation.

### 4. GitHub issues

- For every GitHub repository whose option is not `Ignore`, issues are retrieved from `GET {base URL}/repos/{owner}/{repo}/issues?state=all`, so **open and closed** issues are both retrieved.
- **Pull requests are skipped.** The issues endpoint also returns pull requests; items that have a `pull_request` property are not stored.
- Issues are stored in the shared **Issue** table (section 6).

### 5. Azure DevOps user stories and tasks

- For every Azure DevOps project whose option is not `Ignore`, the app retrieves all work items of type **User Story** and **Task** in that project, in every state.
- Retrieval takes two steps:
  - a WIQL query (`POST {base URL}/{project}/_apis/wit/wiql`) returns the ids of the matching work items;
  - the work items themselves are retrieved in batches (`POST {base URL}/{project}/_apis/wit/workitemsbatch`, at most 200 ids per request), with only the fields that are stored.
- Work item type names are those of the Agile process (`User Story`, `Task`). Projects that use another process (for example Scrum's `Product Backlog Item`) return no user stories.
- Work items are stored in the shared **Issue** table (section 6).
- **Pull requests are not retrieved.** In Azure DevOps, pull requests belong to Azure Repos and are not work items, so the query above never returns them. Nothing else from Azure Repos is retrieved either.

### 6. The shared Issue table

- GitHub issues and Azure DevOps work items are stored in one **Issue** table, with a list page, linked to their repository or project.
- Only a minimal set of data is stored:
  - **Source Type**: enum `GitHub` or `Azure DevOps`, from the base URL.
  - **Id**: the GitHub issue `id` or the Azure DevOps work item id. Together with the base URL it is the key.
  - **Number**: the per-repository issue `number` (the `#123` users see) for GitHub; the work item id for Azure DevOps.
  - **Type**: enum `Issue` (GitHub), `User Story` or `Task` (Azure DevOps).
  - **Description**: the GitHub issue `title` or the work item `System.Title`, as `Text[256]` (confirmed). The issue body and work item description are not stored.
  - **State**: enum "Issue State" with the values `Open` and `Closed`.
    - GitHub: mapped from the `state` field (`open` / `closed`).
    - Azure DevOps: mapped from the state's category. States in the categories `Completed` and `Removed` become `Closed`; all others become `Open`.
  - **Parent Id** (Azure DevOps only): the id of the parent work item (`System.Parent`), 0 when there is none.
- **User stories and their tasks must be recognisable.** The issue list shows the Type, the Parent Id and the parent's description. It shows Azure DevOps work items as a collapsible tree: each user story with its child tasks indented below it. A task whose parent is not a stored user story is shown at the top level, with its Parent Id.

### 7. Data retrieval with the Rest Client

- All data is retrieved with Codeunit "Rest Client" from the System Application.
- The data is updated in two ways, which run the **same logic**:
  - **Job Queue (scheduled):** a codeunit that can run as a Job Queue Entry updates everything:
    - for every owner of every GitHub base URL: the repositories, then the issues of every repository that is not `Ignore`;
    - for every Azure DevOps base URL: the projects, then the user stories and tasks of every project that is not `Ignore`.
    - There is **one** Job Queue Entry for all base URLs; it uses no parameter string. All base URLs share its schedule.
    - The settings page has an action that creates this Job Queue Entry (if it does not exist yet) and opens it, so the user only sets the schedule.
    - An error for one owner, base URL, repository or project does not stop the others. The failures are collected, and at the end the Job Queue Entry ends with an error that names them, so the failure is visible in the Job Queue log.
  - **Manual:** page actions to update on demand:
    - on the owners page: update the repositories, or the repositories and their issues, of the selected owners;
    - on the settings page: update the projects, or the projects and their work items, of the selected Azure DevOps base URLs;
    - on the repository page: update the issues or work items of the selected repositories and projects.
- A manual update and a scheduled update must not run at the same time for the same data; the second one waits or stops with a clear message.
- **Paging:**
  - GitHub: every request asks for **50 items per page** (`per_page=50`) and follows the pages until all items are retrieved.
  - Azure DevOps: the project list is followed until all projects are retrieved. Work items are retrieved in batches of at most 200 ids, the API maximum.

### 8. Repeated retrieval (upsert and removal)

- Retrieving the same data again must **not** cause an error, for example a duplicate key.
- An existing repository, project, issue or work item is **updated**, and a new one is inserted.
- Records are identified by their GitHub or Azure DevOps id within their base URL.
- Records that are no longer returned are **removed**:
  - A repository that is no longer returned for its owner is deleted, together with its issues.
  - A project that is no longer returned for its base URL is deleted, together with its work items.
  - An issue or work item that is no longer returned for its repository or project is deleted. This includes a work item whose type changed to something other than User Story or Task.
- Removal only happens after **all pages** (or batches) of that owner, base URL, repository or project were retrieved successfully. If a request fails halfway, nothing is deleted, so a network or rate-limit error never wipes data.

## Deliverables

- Tables and fields for settings (base URLs), owners, repositories/projects and issues/work items.
- Enum "Source Type", used on the settings, repository and issue tables.
- Enum "Owner Type", used on the owner table.
- Enum "Issue Sync" (extensible), used on the repository table.
- Enum "Issue Type" (`Issue`, `User Story`, `Task`), used on the issue table.
- Enum "Issue State", used on the issue table.
- Pages for each table: settings, owners, repository list and issue list (with the user story / task tree).
- Action "Delete Issues" on the repository page.
- A codeunit that runs as a Job Queue Entry, plus an action on the settings page to create it.
- Page actions for a manual update on the owners, settings and repository pages.
- Retrieval logic using Codeunit "Rest Client", following the project rules in `.claude/rules/`.

## Open questions

None at the moment.
