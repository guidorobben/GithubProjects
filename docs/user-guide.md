# GithubProjects Business Central – User Guide

## About this extension

GithubProjects brings repositories and issues from GitHub, and user stories and tasks from Azure DevOps, into Business Central. This guide covers what is available so far: registering the GitHub and Azure DevOps addresses (base URLs) the extension connects to, each with its own personal access token, and retrieving the repositories of GitHub users and organizations. Retrieving issues, Azure DevOps projects and work items follows in later versions.

## Table of contents

- [Base URLs and tokens](#base-urls-and-tokens)
- [GitHub owners and repositories](#github-owners-and-repositories)

## Base URLs and tokens

### What this feature does

On the **Base URLs** page you register every GitHub or Azure DevOps address that GithubProjects connects to, for example `https://api.github.com` for github.com or `https://dev.azure.com/{organization}` for an Azure DevOps organization. Each base URL has a **Code**, a **URL** and a **Source Type** (**GitHub** or **Azure DevOps**), and its own personal access token. The token is stored securely and can never be read back on any page: the list only shows whether a token is set. Tokens are kept per company. For GitHub, the base URL is the address of the API, not of the website: use `https://api.github.com`, not `https://github.com`. Repositories are retrieved for GitHub base URLs (see [GitHub owners and repositories](#github-owners-and-repositories)); Azure DevOps base URLs can be registered, but nothing is retrieved from Azure DevOps yet.

### Setup

**Before you start: permissions**

GithubProjects has two permission sets:
- **GitHub Projects - Admin** (**PROJECTS ADMIN GHP**): create, change and delete base URLs and owners, and set and clear tokens. It includes the User permission set, so an admin does not need both.
- **GitHub Projects - User** (**PROJECTS USER GHP**): open the **Base URLs**, **Owners** and **Repositories** pages, see whether a token is set, run **Update Repositories**, change **Issue Sync** on a repository, and delete repositories. A user with only this permission set cannot change base URLs or owners; **Set Token** and **Clear Token** are refused with "You do not have permission to change the token of base URL …".

These permission sets only cover GithubProjects. Users also need their usual Business Central permissions to sign in and work in the client. Assigning permission sets is done by someone with permission to manage users:

1. Open the user card of the user.
2. In the **User Permission Sets** section, in the **Permission Set** column, choose **PROJECTS ADMIN GHP** or **PROJECTS USER GHP**.

**Register a base URL**

1. Choose the search icon, enter **Base URLs**, and choose the related link.
2. On a new line, fill in **Code** and **URL**.
3. Check **Source Type**. A new line gets **GitHub**; change it to **Azure DevOps** for an Azure DevOps organization.
4. Move to another line. The base URL is saved.
5. Set the token for the line, as described under **Set or replace a token** below. The line then shows **Token Set** = **Yes**.

Rules for the **URL**:
- It must start with `https://` (capitals are also accepted). Any other address is refused with the message "The URL … must start with https://.".
- Spaces at the start and end, and any slashes at the end, are removed when you enter the URL. `https://api.github.com/` is saved as `https://api.github.com`.
- Each URL can be used once. The same URL with different capitals or a trailing slash counts as the same URL; it is refused with the message "The URL … is already used by base URL …".
- A line cannot be saved without a URL: Business Central shows a message that **URL** must have a value.

Good to know:
- You can save a base URL without a token. A GitHub base URL without a token only returns public repositories, and GitHub allows only 60 requests per hour without a token. Once Azure DevOps is supported, an Azure DevOps base URL will need a token.
- Changing the **URL** or renaming the **Code** keeps the token.
- Deleting a base URL also deletes its token, its owners and their repositories.
- The **Source Type** cannot be changed once the base URL has owners: "You cannot change the Source Type of base URL … because it has owners.".

### How to use

**Set or replace a token**

1. On the **Base URLs** page, select the line of the base URL.
2. Choose **Set Token**. The **Enter Password** dialog opens with one masked **Password** field.
3. Paste the personal access token into **Password** and choose **OK**.
4. No message is shown. **Token Set** on the line changes to **Yes**.

The action only works on the current line (the line where the cursor is). If you select several lines, only the current line gets the token. An existing token is replaced without a question.

**Set Token** is refused, in this order:
- when you do not have the **GitHub Projects - Admin** permission set: "You do not have permission to change the token of base URL …". The dialog does not open.
- when the line has not been saved yet: "Save the base URL before you set its token.".

If you choose **Cancel**, the token does not change. If you choose **OK** without entering a value, Business Central asks "Do you want to exit without entering a password?". When you answer **Yes**, the dialog closes and the token does not change. When you answer **No**, the dialog stays open so you can enter the token.

**Remove a token**

1. On the **Base URLs** page, select the line of the base URL.
2. Choose **Clear Token**.
3. Answer **Yes** to "Do you want to clear the token of base URL …?". The default answer is **No**; if you answer **No**, the token is kept.
4. No message is shown. **Token Set** on the line changes to **No**.

**Clear Token** only works on the current line. Without the **GitHub Projects - Admin** permission set it is refused with "You do not have permission to change the token of base URL …". When the line has no token, nothing happens and no question is asked. To remove a token, always use **Clear Token**.

Good to know:
- **Tokens and environment copies (Business Central online):** when an environment is copied in the Business Central admin center, the tokens of all base URLs are deleted in every company of the copy. The base URLs themselves are kept. This happens on every copy, also when the copy is a production environment. Set the tokens again in the copy.
- **Tokens per company:** a token belongs to one company. Base URLs are also per company, so set them up in every company that needs them. **Copy Company** copies the base URLs but not their tokens: in the new company **Token Set** shows **No**, so set the tokens again there.

## GitHub owners and repositories

### What this feature does

For a GitHub base URL you list the GitHub users and organizations (owners) whose repositories you want in Business Central. **Update Repositories** retrieves their repositories from GitHub and keeps the **Repositories** list up to date: new repositories are added, changed ones are updated, and repositories that GitHub no longer returns are deleted. Which repositories GitHub returns depends on the owner:
- **User** whose **Name** is the account the base URL's token belongs to: the repositories this account owns, including private ones.
- **User** for any other account: only public repositories.
- **Organization**: the public repositories, plus the private ones the token can access.

Owners only exist for GitHub base URLs. Issues are not retrieved yet; **Issue Sync** and **Issues Enabled** prepare for that.

### Setup

To maintain owners, you need the **GitHub Projects - Admin** permission set (see [Base URLs and tokens](#base-urls-and-tokens)).

1. On the **Base URLs** page, select the line of a GitHub base URL, for example `https://api.github.com`.
2. Choose **Owners**. The **Owners** page opens for that base URL. If you open **Owners** through search instead, also fill in **Base URL Code** on each new line.
3. On a new line, fill in **Name**: the GitHub account name as in `https://github.com/{name}`, for example `microsoft`. Do not enter a repository name.
4. Set **Owner Type** to **User** for a personal account or **Organization** for an organization. A new line gets **User**.
5. Move to another line. The owner is saved, with **Repository Sync** = **Include**.

Rules for owners:
- The base URL must have **Source Type** **GitHub**. Otherwise: "Owners can only be added to a base URL with Source Type GitHub. Base URL … is not a GitHub base URL.". The list of base URLs to choose from also shows Azure DevOps base URLs.
- **Name** may only contain letters (a–z, A–Z, without accents), digits, hyphens (-) and underscores (_); otherwise: "The owner name … can only contain letters, digits, hyphens (-) and underscores (_).". Spaces at the start and end are removed.
- The same name can be used once per base URL, regardless of capitals: "Owner … already exists for base URL …".
- An owner cannot be renamed: "An owner cannot be renamed. Delete the owner and create a new one.".

Good to know:
- Choose **Owner Type** carefully. A user set to **Organization** fails with status 404 Not Found when you update it. An organization left on **User** gives no error, but only its public repositories are retrieved.
- Deleting an owner also deletes its stored repositories.
- **Repository Sync** = **Ignore** makes **Update Repositories** skip the owner. Its stored repositories are kept as they are.
- Set a token on the base URL for regular use. Each owner needs one request to GitHub per 50 repositories, and without a token GitHub accepts only 60 requests per hour.
- In a sandbox, Business Central blocks requests to GitHub until you allow them for this extension. Someone with permission to manage extensions does this: search for **Extension Management**, select **GitHub Projects**, choose **View**, and turn on **Allow HttpClient Requests** in **Extension Settings**.

### How to use

**Retrieve the repositories of owners**

1. Choose the search icon, enter **Owners**, and choose the related link, or choose **Owners** on the **Base URLs** page.
2. Select the owners you want to update. You can select several lines. If you do not select lines, only the current line is updated; to update all owners, select all lines first.
3. Choose **Update Repositories**.
4. When all selected owners are updated, a message says how many: "The repositories of … owner(s) were updated.". If some selected owners are set to **Ignore**, the message also says how many were skipped.
5. **No. of Repositories** on each owner shows the number of stored repositories.

Each owner is updated on its own, and all selected owners are processed before any error is shown:
- If GitHub refuses a request for an owner, nothing of that owner is changed, and the other owners are still updated. Typical causes: a wrong **Name** or **Owner Type** (status 404 Not Found), or an expired or invalid token (status 401; then every owner of that base URL fails, its repositories are kept, and you set a new token on the **Base URLs** page).
- If GitHub's rate limit is reached (the maximum number of requests GitHub accepts per hour), the owner that reached it and the remaining owners of that base URL are not updated in this run. Owners of other base URLs are still updated.
- At the end, an error lists what failed instead of the success message: "The repositories of … owner(s) could not be updated:", followed by at most 10 lines and "...and … more." when there are more. The number includes the owners skipped because of the rate limit. A line looks like this:
  - `GITHUB microsoft: The request to https://api.github.com/orgs/microsoft/repos?per_page=50 failed with status 404 Not Found.`
  - `GITHUB: GitHub rate limit reached; 2 owner(s) skipped. The limit resets at …`
- All owners that were updated successfully keep their changes, even though an error is shown at the end. Refresh the page (F5) to see the current **No. of Repositories**.

**View the repositories**

1. On the **Owners** page, select an owner and choose **Repositories**. The **Repositories** page opens with that owner's repositories.
2. The list shows **Source Type**, **Name**, **Issues Enabled** and **Issue Sync**. **Base URL Code** and **Owner** are hidden; add them through personalization if you need them. When you open **Repositories** through search, it shows the repositories of all owners, sorted by base URL, owner and name, so show **Owner** to tell them apart.

- **Issues Enabled** shows whether issues are turned on for the repository in GitHub. It does not say whether the repository has issues.
- **Issue Sync** (**Include** or **Ignore**) is your choice for retrieving issues later. A new repository gets **Include**, and **Update Repositories** never changes it. It has no effect yet.
- You cannot add repositories yourself; **Update Repositories** maintains the list. You can delete a repository line, but it comes back the next time its owner is updated, with **Issue Sync** **Include**. To stop updating an owner's repositories altogether, set the owner's **Repository Sync** to **Ignore**.

Good to know:
- **Private repositories:** when the token is removed or replaced by a token of another account, the private repositories of the old account are no longer returned and are deleted at the next update.
- **Moved repositories:** when a repository moves to another owner that is also on the **Owners** list of the same base URL, it moves to that owner at the next update and keeps its **Issue Sync**, unless the old owner is updated first in the same run: then it is deleted there and added again with **Issue Sync** **Include**. When the new owner is not on the list, the repository is deleted at the old owner's next update.
- Repositories are only updated when you choose **Update Repositories**.