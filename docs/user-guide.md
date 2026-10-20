# GithubProjects Business Central – User Guide

## About this extension

GithubProjects brings repositories and issues from GitHub, and user stories and tasks from Azure DevOps, into Business Central. This guide covers the first part that is available: registering the GitHub and Azure DevOps addresses (base URLs) the extension connects to, each with its own personal access token. Retrieving repositories, issues and work items is not available yet; it follows in later versions.

## Table of contents

- [Base URLs and tokens](#base-urls-and-tokens)

## Base URLs and tokens

### What this feature does

On the **Base URLs** page you register every GitHub or Azure DevOps address that GithubProjects connects to, for example `https://api.github.com` for github.com or `https://dev.azure.com/{organization}` for an Azure DevOps organization. Each base URL has a **Code**, a **URL** and a **Source Type** (**GitHub** or **Azure DevOps**), and its own personal access token. The token is stored securely and can never be read back on any page: the list only shows whether a token is set. Tokens are kept per company. This version only stores the base URLs and tokens; no data is retrieved from GitHub or Azure DevOps yet.

### Setup

**Before you start: permissions**

GithubProjects has two permission sets:
- **GitHub Projects - Admin** (**PROJECTS ADMIN GHP**): create, change and delete base URLs, and set and clear tokens. It includes the User permission set, so an admin does not need both.
- **GitHub Projects - User** (**PROJECTS USER GHP**): open the **Base URLs** page and see whether a token is set. A user with only this permission set cannot change base URLs; **Set Token** and **Clear Token** are refused with "You do not have permission to change the token of base URL …".

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
- You can save a base URL without a token. Once retrieving data is available, a GitHub base URL without a token will only return public data (GitHub allows 60 requests per hour without a token), and an Azure DevOps base URL will need a token.
- Changing the **URL** or renaming the **Code** keeps the token.
- Deleting a base URL also deletes its token.

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
