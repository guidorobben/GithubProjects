# Requirements — Base URLs and tokens

Roadmap: [1. Base URLs and tokens](../roadmap.md#1-base-urls-and-tokens).
Tech design: [§1 Settings: multiple base URLs](../tech-design.md#1-settings-multiple-base-urls), key decisions 1, 2, 16, 17; [Cross-cutting](../tech-design.md#cross-cutting) (permissions, data classification).
Brief: [§1 Settings: multiple base URLs](../brief.md#1-settings-multiple-base-urls), all bullets.
Apps: GithubProjects, GithubProjects.Test (new). Branch: `spec/2026-10-20-base-urls-and-tokens`.

## Goal

The user can register GitHub and Azure DevOps base URLs, each with its own secret token.

## Definitions

- **Base URL**: one record in Table "Base URL GHP": a Code, a URL and a Source Type. Later features attach owners, repositories, projects and issues to it.
- **Token**: the personal access token of one base URL. It is stored in Isolated Storage with `DataScope::Company`, under a key derived from the base URL's `SystemId`. It is never stored in a table field.
- **Normalised URL**: the entered URL with leading and trailing spaces removed and all trailing `/` characters removed.
- **Admin**: a user with write permission (insert, modify and delete) on Table "Base URL GHP", for example through permission set "Projects Admin GHP".

## Functional requirements

### R1 — Base URL records

- R1.1 An admin can create, change, rename and delete base URLs on Page "Base URLs GHP". Each base URL has a Code (`Code[20]`, required, primary key).
- R1.2 Each base URL has a URL (`Text[250]`) and a Source Type (Enum "Source Type GHP": `GitHub`, `Azure DevOps`). A new base URL gets Source Type `GitHub`.
- R1.3 A base URL cannot be inserted or modified with a blank URL.
- R1.4 When the URL is validated, it is replaced by its normalised URL (e.g. `  https://api.github.com/ ` becomes `https://api.github.com`).
- R1.5 The URL must start with `https://` (in any case). Any other URL is refused with an error. (Addition to the tech design, decided 2026-10-20: the token is sent to this URL, so it must never go over plain HTTP.)
- R1.6 Two base URLs cannot have the same normalised URL, regardless of case. The error names the Code of the base URL that already uses it.
- R1.7 Renaming the Code or changing the URL keeps the token.
- R1.8 The rules R1.3–R1.6 are checked when the URL is validated and again when the record is inserted or modified with triggers, so a caller that assigns the URL without validating it cannot bypass them.

### R2 — Token

- R2.1 Action "Set Token" opens the standard masked password dialog with one field (no confirmation field, no password-strength check). When the user chooses OK with a value, that value becomes the token of the base URL and replaces any existing token.
- R2.2 When the user cancels the dialog or chooses OK without a value, the token is not changed.
- R2.3 Action "Clear Token" asks for confirmation when a token exists. Yes deletes the token; No keeps it. When no token exists, nothing happens and no question is asked.
- R2.4 The list shows a read-only "Token Set" (Yes/No) per base URL. The token value is never shown on any page and cannot be read back through any public procedure.
- R2.5 The "Token Set" tooltip explains that a GitHub base URL without a token only returns public data and is limited to 60 requests per hour, and that an Azure DevOps base URL requires a token.
- R2.6 "Set Token" on a base URL that has not been saved yet stops with an error, and no token is stored.
- R2.7 Deleting a base URL deletes its token.
- R2.8 Each base URL has its own token: setting or clearing the token of one base URL does not change the token of another.
- R2.9 Tokens are kept per company: a token set in one company does not exist in another company.
- R2.10 Later features in this app can read the token as `SecretText` through an internal procedure. No other app can, except the test app. The earlier `internalsVisibleTo` entry for "Bluace Library" is removed (decided 2026-10-20).

### R3 — Write permission for tokens

- R3.1 Setting and clearing a token requires write permission (insert, modify and delete) on Table "Base URL GHP". Without it, both stop with an error before the dialog or the confirmation opens, and the token is not changed.
- R3.2 The check is in the procedure that every caller uses, not only on the page.
- R3.3 A user without write permission can still open the list and see "Token Set".

### R4 — Environment copy

- R4.1 After an environment copy, the tokens of all base URLs in each company of the copy are deleted. The base URL records themselves are kept, so the user only has to set the tokens again.

### R5 — Permission sets

- R5.1 Permission set "Projects User GHP" gives read access to base URLs and lets the user open the list.
- R5.2 Permission set "Projects Admin GHP" includes "Projects User GHP" and adds full access to base URLs, and with that the right to set and clear tokens.

## Non-functional requirements

- **Secrets**: the token only exists as `SecretText` in AL. It is never assigned to `Text`, never logged and never shown. The procedure that reads it from Isolated Storage is `[NonDebuggable]`.
- **Translations**: every user-facing text is a Label or a Caption, translated into en-US and nl-NL in the app and the test app (decided 2026-10-20).
- **Structure**: table procedures only call the helper codeunit; pages only call table procedures; every write passes RunTrigger explicitly (`.claude/rules/bluace-*.md`).
- **No change** to standard objects or other apps.
- **Tests**: automated tests in GithubProjects.Test. This feature makes no external calls.
- **Data classification**: Code, URL and Source Type are `CustomerContent`. The token is not in a table.

## Explicitly NOT included

- Sending the token: the GitHub bearer header and Azure DevOps basic authentication belong to the API clients of features 2 and 4.
- An Azure DevOps base URL without a token is allowed here. The update stops on it in feature 4.
- Blocking a Source Type change once owners, repositories or projects exist. Those tables do not exist yet; features 2 and 4 add the check to the Source Type validation.
- Cascading a base URL delete to owners, repositories and issues (features 2–5).
- The "Create Job Queue Entry" action and the manual update actions on this page (features 4 and 6).
- A "test connection" action that checks the token against the API.
- A token field or masked page variable on the list, and `MaskType = Concealed`: rejected in tech design key decision 2.
- `IsolatedStorage.SetEncrypted`: rejected because it limits values to 215 characters (tech design §1).
- Azure DevOps Server (on-premises) URLs: out of scope in the brief. They are not blocked by a URL check.
- Accepted risk: an admin can change the URL of a base URL that has a token, and the token then goes to the new host. Only admins can do this, and keeping the token on a URL change is the reason for the surrogate key (tech design decision 16).
- Accepted risk: a base URL deleted without triggers (`Delete(false)`) leaves its token in Isolated Storage. The key is derived from a `SystemId` that no longer exists, so the token is never used again.
- What "Copy Company" does with company-scoped Isolated Storage is not specified. It is observed once in manual check M2 and documented.
