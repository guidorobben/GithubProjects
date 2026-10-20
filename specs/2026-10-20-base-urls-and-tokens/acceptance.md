# Acceptance — Base URLs and tokens

Defines done for [requirements.md](requirements.md).

- **Sections A–E are automated tests** in GithubProjects.Test (see [plan.md](plan.md#test-app-automated-tests)). A–E run in the AL Test Tool and the AL-Go pipeline. The AL MCP test runner also runs them (`company: "CRONUS NL"`), but it does **not** fail on unhandled dialogs: E3 passed there while the AL Test Tool reported "Unhandled UI: Confirm" (2026-10-20). Scenarios that prove "no dialog" (B7, C2, C3) therefore only count when run in the AL Test Tool or the pipeline. This feature makes no external calls. Test URLs use the `.invalid` host anyway.
- **Section M is the short manual list.** It covers what a test cannot prove: a real environment copy, Copy Company, and how the standard dialog looks.

## Conventions for the automated tests

- **Test data**, created through "Library - Base URL GHP":
  - **GH**: Source Type `GitHub`, URL `https://gh-<random>.invalid`.
  - **AZ**: Source Type `Azure DevOps`, URL `https://az-<random>.invalid`.
  - **Dummy token**: a non-empty `SecretText` built with `SecretStrSubstNo`.
- **Token checks**: "has a token" means `HasToken() = true` and `GetToken().IsEmpty() = false`. "Has no token" means `HasToken() = false` and `GetToken().IsEmpty() = true`. The value itself cannot be read in a cloud test app (plan.md).
- **No dialog** means the test has no `ModalPageHandler` or `ConfirmHandler`, so any dialog fails the test.
- **Messages** are asserted in full against test labels with the app's English text (`bluace-testing.md` Rule 7).
- **Permissions**: sections A, B, D and E run with the test user's own permissions. Section C starts "Permissions Mock", uses `SetExactPermissionSet` with the set under test and adds the test-framework set "Projects Test GHP" (no table data) (`bluace-testing.md` Rule 3).
- Test procedure names start with the ID, e.g. `B5_ClearTokenConfirmedDeletesToken` (`bluace-testing.md` Rule 5).

## A. Base URL records (R1)

| # | Given | When | Then |
| --- | --- | --- | --- |
| A1 | No base URL with code `A1` | A record with Code `A1` and URL `https://a1.invalid` is inserted with triggers, Source Type not set | It exists with Source Type `GitHub` (R1.1, R1.2) |
| A2 | A new record | URL is validated with `  https://api.github.com//  ` | URL = `https://api.github.com` (R1.4) |
| A3 | A new record with a blank URL | It is inserted with triggers | A TestField error on URL; the record does not exist (R1.3) |
| A4 | A new record | URL is validated with `http://api.github.com` | Error `UrlMustBeHttpsErr` with that URL (R1.5) |
| A4a | A new record | URL is validated with `HTTPS://Upper.invalid` | No error; the value is kept (R1.5) |
| A5 | GH exists with URL `https://dup.invalid` | Another record validates URL `HTTPS://DUP.INVALID/` | Error `DuplicateUrlErr` naming URL `HTTPS://DUP.INVALID` and GH's Code (R1.6) |
| A5a | GH exists | GH itself validates its own URL again | No error (R1.6) |
| A6 | A new record | URL is assigned `http://bypass.invalid` without validation, then inserted with triggers | Error `UrlMustBeHttpsErr`; the record does not exist (R1.8) |
| A6a | GH and AZ exist | AZ's URL is assigned GH's URL without validation, then modified with triggers | Error `DuplicateUrlErr`; AZ keeps its URL (R1.8) |
| A7 | GH has the dummy token | GH is renamed to a new Code | The renamed record has a token (R1.7) |
| A8 | GH has the dummy token | GH's URL is validated with `https://moved.invalid` and modified | GH has a token (R1.7) |

## B. Token (R2)

| # | Given | When | Then |
| --- | --- | --- | --- |
| B1 | GH has no token | `SetToken(dummy)` | GH has a token (R2.1, R2.10) |
| B2 | GH has a token | `SetToken(another dummy)` | GH has a token; no error (R2.1) |
| B3 | GH committed, no token | Inside `asserterror`: `SetToken(dummy)`, then an error | GH has no token: the write was rolled back with the transaction (plan.md, Transactions) |
| B4 | GH has a token | `SetToken` with an empty `SecretText` | GH still has a token (R2.2) |
| B5 | GH has a token | `ClearToken()`, ConfirmHandler answers Yes and checks the question `ClearTokenQst` with GH's Code | GH has no token (R2.3) |
| B6 | GH has a token | `ClearToken()`, ConfirmHandler answers No | GH has a token (R2.3) |
| B7 | GH has no token | `ClearToken()` with no dialog | No error, no question (R2.3) |
| B8 | GH has a token | GH is deleted with triggers, then a record with GH's Code and `SystemId` is inserted again (`Insert(true, true)`) | It has no token (R2.7) |
| B9 | An initialised record that was never inserted | `SetToken(dummy)` | Error `SaveBaseUrlFirstErr`; no record and no token exist (R2.6) |
| B10 | GH and AZ both have a token | `ClearToken()` on GH (Yes) | GH has no token; AZ has a token (R2.8) |
| B11 | AZ has never had a token | `GetToken()` | Returns an empty `SecretText`; no error (R2.10) |

## C. Permissions (R3, R5)

| # | Given | When | Then |
| --- | --- | --- | --- |
| C1 | GH has a token; exact permission set "Projects User GHP" | `SetToken(dummy)` | Error `NoTokenPermissionErr` with GH's Code; GH still has a token (R3.1, R3.2) |
| C2 | GH has no token; "Projects User GHP" | `SetToken()` (dialog version) with no dialog | Error `NoTokenPermissionErr`; no dialog opened; GH has no token (R3.1) |
| C3 | GH has a token; "Projects User GHP" | `ClearToken()` with no dialog | Error `NoTokenPermissionErr`; no question; GH still has a token (R3.1) |
| C4 | GH has a token; "Projects User GHP" | GH is read with `Get` and `HasToken()` is called | Both succeed; `HasToken()` = true (R3.3, R5.1) |
| C5 | "Projects User GHP" | A new base URL is inserted | An error; the record does not exist (R5.1) |
| C6 | GH has no token; exact permission set "Projects Admin GHP" | `SetToken(dummy)`, then `ClearToken()` (Yes) | Both succeed; GH has a token after the first and none after the second (R5.2) |

## D. Environment copy (R4)

| # | Given | When | Then |
| --- | --- | --- | --- |
| D1 | GH and AZ both have a token | `DeleteAllTokens()` on an empty Base URL record, which is what the subscriber calls | GH and AZ have no token; both records still exist (R4.1) |
| D2 | GH and AZ both have a token; the record variable is filtered on GH's Code | `DeleteAllTokens()` | Neither has a token: filters on the variable are ignored (R4.1) |

The binding of the subscriber to the platform event is checked at compile time and in M1. A test cannot raise `OnAfterCopyEnvironmentPerCompany`.

## E. Page "Base URLs GHP" (R1.1, R2.1–R2.4) — TestPage

| # | Given | When | Then |
| --- | --- | --- | --- |
| E1 | GH has no token; the page is open on GH | "Set Token"; the ModalPageHandler on "Password Dialog" enters a value in `Password` and chooses OK | "Token Set" = Yes on GH's row; GH has a token (R2.1, R2.4) |
| E2 | Same as E1 | "Set Token"; the handler enters a value and chooses Cancel | "Token Set" = No; GH has no token (R2.2) |
| E3 | Same as E1 | "Set Token"; the handler chooses OK without a value, and the standard dialog's question "exit without entering a password?" is answered Yes | "Token Set" = No (R2.2) |
| E4 | GH has a token; the page is open on GH | "Clear Token", confirm Yes | "Token Set" = No (R2.3) |
| E5 | GH has a token, AZ has none | The page is opened and moves from GH to AZ | "Token Set" is Yes on GH and No on AZ: the value is per row (R2.4) |
| E6 | The page is open | – | "Token Set" is not editable (R2.4) |
| E7 | The page is open in a new row | Code `E7` and URL `https://e7.invalid/` are entered | The row is saved with URL `https://e7.invalid` (R1.1, R1.4) |

## M. Manual checks

Run once before merge. M1 runs in an online sandbox, because environment copy only exists online. M2 and M3 run in the container `tm2023w2v2-nl`.

| # | Check | Pass when |
| --- | --- | --- |
| M1 | In an online environment with the app, create a base URL and set a token, then copy the environment to a new sandbox in the admin center (R4.1) | In the copy, the base URL exists and "Token Set" = No |
| M2 | Create a base URL with a token in company A, then use Copy Company to create company B. Also open the list in another existing company (R2.9) | The other existing company has no base URLs. For B, what "Token Set" shows is recorded in the PR and the user guide (observation, not a pass/fail) |
| M3 | "Set Token" in the web client, with the tooltip of "Token Set" shown | The dialog shows one masked field, no confirmation field and no way to reveal the value; the tooltip text matches R2.5 in en-US and nl-NL |

## G. Quality gates

- G1 Both apps compile without errors and without new warnings under the workspace analyzers and the Bluace ruleset (`bluace-compile.md`).
- G2 All automated tests pass in the AL-Go pipeline (no external communication). A–D also pass with the AL MCP test runner.
- G3 All user-facing texts are Labels or Captions; en-US and nl-NL translation files are complete in the app and the test app (`bluace-testing.md` Rule 7).
- G4 The token is never in a table field or a `Text` variable: the code contains no `Unwrap`, no `Text` parameter or variable for the token, and the procedure that reads Isolated Storage is `[NonDebuggable]`.
- G5 No standard object and no other app is modified.
- G6 Section M passed, results recorded in the PR.
- G7 After merge: `specs/tech-design.md` (the deviations listed in plan.md), `specs/roadmap.md` (status `done`), `docs/user-guide.md` and `CHANGELOG.md` are updated, per the SDD loop.

## Not covered here

- That the token is sent correctly (bearer for GitHub, basic for Azure DevOps), and that a replaced token is used: features 2 and 4, through the mock handler.
- Refusing a Source Type change when dependent data exists: features 2 and 4.
- Cascading a base URL delete to owners, repositories and issues: features 2–5.
