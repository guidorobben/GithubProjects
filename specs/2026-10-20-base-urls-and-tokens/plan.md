# Plan — Base URLs and tokens

Implements [requirements.md](requirements.md) as decided in [tech-design.md §1](../tech-design.md#1-settings-multiple-base-urls).
App: GithubProjects, a per-tenant extension (ID range 80000–80099, runtime 17.0, application and platform 28.0.0.0; symbols 28.5). Standard objects are not modified.

## Naming and structure

- Every object name ends with ` GHP` (`GithubProjects/AppSourceCop.json` `mandatoryAffixes`). Names stay within 30 characters. Assignable permission sets stay within 20 characters (Learn, *Permission set object*: AL0305).
- Captions have no suffix. File names follow `<ObjectNameWithoutSuffix>.<ObjectType>.al` (`.vscode/settings.json` `CRS.RemoveSuffixFromFilename`).
- The helper codeunit and the subscriber are `Access = Internal` (`bluace-helper-codeunits.md` Rule 2). Pages cannot be `Access = Internal` (`bluace-compile.md` Rule 3).
- Folders (`bluace-folder-structure.md`):

```
GithubProjects/src/
├── BaseURL/
│   ├── BaseURL.Table.al
│   ├── BaseURLHelper.Codeunit.al
│   ├── BaseURLs.Page.al
│   └── SourceType.Enum.al
├── General/
│   └── EnvTriggerSubscr.Codeunit.al
└── PermissionSets/
    ├── ProjectsAdmin.PermissionSet.al
    └── ProjectsUser.PermissionSet.al
```

- **ID ranges and analyzers:** GithubProjects is a per-tenant extension for now and uses 80000–80099; the test app uses 50000–50099 (both decided 2026-10-20). Both apps compile with `${PerTenantExtensionCop}`, not `${AppSourceCop}` (`.vscode/settings.json`, decided 2026-10-20), as `bluace-compile.md` Rule 1 prescribes.
- **`internalsVisibleTo`:** the entry for "Bluace Library" is replaced by the test app (decided 2026-10-20; already applied to `GithubProjects/app.json`).
- **Deviations from the tech design**, to be written back in the Docs step:
  1. R1.5: the URL must start with `https://` (confirmed 2026-10-20).
  2. The URL rules are also checked on insert and modify (R1.8), not only on validate.
  3. "Token Set" is a page variable filled from `Rec.HasToken()` in `OnAfterGetRecord`, not a field. Isolated Storage cannot back a FlowField.
  4. The Source Type change lock (tech design §1) moves to features 2 and 4.
- **ID range history (2026-10-20):** the original range 70861875–70861974 was shared with Bluace app "Base Functionality", which uses 70861875–70861913, so publishing failed. The app moved to the per-tenant range 80000–80099.

## Objects

| Type | ID | Name | Caption | File | Folder |
| --- | --- | --- | --- | --- | --- |
| Enum | 80000 | Source Type GHP | Source Type | SourceType.Enum.al | src/BaseURL |
| Table | 80000 | Base URL GHP | Base URL | BaseURL.Table.al | src/BaseURL |
| Page | 80000 | Base URLs GHP | Base URLs | BaseURLs.Page.al | src/BaseURL |
| Codeunit | 80000 | Base URL Helper GHP | – | BaseURLHelper.Codeunit.al | src/BaseURL |
| Codeunit | 80001 | Env. Trigger Subscr. GHP | – | EnvTriggerSubscr.Codeunit.al | src/General |
| PermissionSet | 80000 | Projects User GHP | GitHub Projects - User | ProjectsUser.PermissionSet.al | src/PermissionSets |
| PermissionSet | 80001 | Projects Admin GHP | GitHub Projects - Admin | ProjectsAdmin.PermissionSet.al | src/PermissionSets |

## Enum "Source Type GHP" (R1.2)

`Extensible = false` (tech design key decision 13: each value needs its own API client). Values: `0 GitHub` (caption 'GitHub'), `1 "Azure DevOps"` (caption 'Azure DevOps').

## Table "Base URL GHP" (R1, R2, R3, R4)

`DataClassification = CustomerContent`, `Caption = 'Base URL'`, `LookupPageId`/`DrillDownPageId` = Page "Base URLs GHP".

| No. | Name | Type | Properties | Triggers |
| --- | --- | --- | --- | --- |
| 1 | Code | Code[20] | `NotBlank = true` | – |
| 2 | URL | Text[250] | `ExtendedDatatype = URL` | `OnValidate` → `ValidateUrl()` (R1.4–R1.6) |
| 3 | Source Type | Enum "Source Type GHP" | – | – |

Keys: `PK` (Code, clustered); `URL` (URL), `Unique = true`. The unique key is the database backstop for R1.6 (Learn: *Unique property*). It does not replace the helper's check, which gives a readable error.

Table triggers (`bluace-helper-codeunits.md` Rule 2: they only call the helper):
- `OnInsert`, `OnModify` → `BaseURLHelper.CheckUrl(Rec)` (R1.3, R1.5, R1.6, R1.8).
- `OnDelete` → `BaseURLHelper.DeleteToken(Rec)` (R2.7).
- No `OnRename` logic. `SystemId` cannot change once set (Learn: *Work with table system fields*), so the token key survives a rename (R1.7, verified by test A7).

Procedures. Each calls the procedure with the same name on the global `BaseURLHelper: Codeunit "Base URL Helper GHP"`:

| Procedure | Access | Requirement |
| --- | --- | --- |
| `SetToken()` | public | R2.1, R2.2, R2.6, R3.1 (dialog) |
| `SetToken(Token: SecretText)` | internal | R2.1, R2.6, R3.1, without dialog. Used by tests; feature-agnostic |
| `ClearToken()` | public | R2.3, R3.1 |
| `HasToken(): Boolean` | public | R2.4 |
| `GetToken(): SecretText` | internal | R2.10. For the API clients of features 2 and 4 |
| `DeleteAllTokens()` | internal | R4.1. Acts on all base URLs in the current company, ignoring filters on `Rec` |

`internal` procedures are visible to the test app through `internalsVisibleTo` (see the test app section). They are not visible to any other app (R2.10).

## Codeunit "Base URL Helper GHP" (R1–R4)

`Access = Internal`. No `Permissions` property is needed: it only reads Table "Base URL GHP", and the user who runs the action already has read access through either permission set.

Procedures:
- `ValidateUrl(var BaseURL)`: normalises the URL (`DelChr` of leading and trailing spaces, then remove trailing `/` in a loop), then `CheckHttps` and `CheckDuplicate`.
- `CheckUrl(var BaseURL)`: `TestField(URL)` (R1.3), then `CheckHttps` and `CheckDuplicate`. It does not normalise: a value written without validation is checked as it is. The normalised form still has to start with `https://` and still has to be unique.
- `local CheckHttps(BaseURL)`: `LowerCase(CopyStr(URL, 1, 8)) = 'https://'`, otherwise `Error(UrlMustBeHttpsErr, URL)`.
- `local CheckDuplicate(BaseURL)`: loops over the other base URLs (`SetFilter(Code, '<>%1', BaseURL.Code)`, `SetLoadFields(Code, URL)`) and compares `LowerCase` values; on a match, `Error(DuplicateUrlErr, URL, Other.Code)`. Decided at implementation: a loop instead of an `@` filter, because a URL can contain filter characters (`&`, `|`, `(`) and the table holds only a few records. Test A5 proves the case-insensitive match.
- `SetToken(var BaseURL)`: `CheckWritePermission`, `CheckSaved`, then `Token := PasswordDialogManagement.OpenSecretPasswordDialog(true, true)`; if `Token.IsEmpty()`, exit (R2.2); else `StoreToken`.
  - Verified (source): `System Application/App/Password/src/PasswordDialogManagement.Codeunit.al:28`. `PasswordDialogImpl.OpenSecretPasswordDialog` returns the value only on `Action::OK`, otherwise an empty `SecretText` (`PasswordDialogImpl.Codeunit.al:30-40`). Confirmed in the 28.5 symbols (System Application).
  - The check runs **before** the dialog, so a user without permission never sees it (R3.1).
- `SetToken(var BaseURL; Token: SecretText)`: `CheckWritePermission`, `CheckSaved`; if `Token.IsEmpty()`, exit; else `StoreToken`.
- `ClearToken(var BaseURL)`: `CheckWritePermission`; if not `HasToken`, exit (R2.3); if `ConfirmManagement.GetResponseOrDefault(StrSubstNo(ClearTokenQst, Code), false)`, then `IsolatedStorage.Delete(GetTokenKey, DataScope::Company)`. Verified (source): `Confirm Management/src/ConfirmManagement.Codeunit.al:39`; in the 28.5 symbols. Default button No.
- `HasToken(BaseURL): Boolean`: `IsolatedStorage.Contains(GetTokenKey(BaseURL), DataScope::Company)`.
- `[NonDebuggable] GetToken(BaseURL): SecretText`: `IsolatedStorage.Get(GetTokenKey(BaseURL), DataScope::Company, Token)` when the key exists; otherwise an empty `SecretText`.
- `DeleteToken(var BaseURL)`: deletes the key if it exists. No permission check: the user already needs delete permission on the table to get here.
- `DeleteAllTokens()`: loops over all records of Table "Base URL GHP" (`SetLoadFields(SystemId)`) and deletes each key that exists.
- `local StoreToken(BaseURL; Token: SecretText)`: `IsolatedStorage.Set(GetTokenKey(BaseURL), Token, DataScope::Company)`. Learn: *IsolatedStorage.Set(Text, SecretText, DataScope)*. Plain `Set`, not `SetEncrypted`: there is no 215-character limit (tech design §1).
- `local CheckWritePermission(BaseURL)`: `if not BaseURL.WritePermission() then Error(NoTokenPermissionErr, BaseURL.Code)`. Learn: *Record.WritePermission*: "A write permission consists of Insert, Delete, and Modify permissions" (R3.1, R3.2).
- `local CheckSaved(BaseURL)`: `if IsNullGuid(BaseURL.SystemId) or not Other.GetBySystemId(BaseURL.SystemId) then Error(SaveBaseUrlFirstErr)` (R2.6).
- `local GetTokenKey(BaseURL): Text`: `StrSubstNo(TokenKeyLbl, Format(BaseURL.SystemId, 0, 4))` with `TokenKeyLbl: Label 'GHP-Token-%1', Locked = true`.

Labels (en-US source):

| Name | Text | Comment |
| --- | --- | --- |
| UrlMustBeHttpsErr | The URL %1 must start with https://. | %1 = URL |
| DuplicateUrlErr | The URL %1 is already used by base URL %2. | %1 = URL, %2 = base URL code |
| NoTokenPermissionErr | You do not have permission to change the token of base URL %1. | %1 = base URL code |
| SaveBaseUrlFirstErr | Save the base URL before you set its token. | – |
| ClearTokenQst | Do you want to clear the token of base URL %1? | %1 = base URL code |
| TokenKeyLbl | GHP-Token-%1 | Locked |

**Transactions:** "Set Token" runs `RunModal` before any write. The permission check only reads, so there is no open write transaction when the dialog opens. Inferred: Isolated Storage writes take part in the transaction like other database writes. Test B3 shows this indirectly: an `asserterror` after `SetToken` rolls the token back.

## Page "Base URLs GHP" (R1.1, R2.1–R2.5, R3.3)

`PageType = List`, `SourceTable = "Base URL GHP"`, `UsageCategory = Administration`, `ApplicationArea = All`, `Caption = 'Base URLs'`, `AdditionalSearchTerms = 'GitHub Projects, Azure DevOps, token'`, `DelayedInsert = true`.

*Added at the Docs step (2026-10-20):* `DelayedInsert = true`. Without it, the client saves a new line as soon as the Code is entered, and the table's `OnInsert` check (URL required, R1.3) refuses it before the user can type the URL.

- Repeater: Code, URL, Source Type, `TokenSet` (page variable, Boolean, `Caption = 'Token Set'`, `Editable = false`, tooltip as R2.5).
- `OnAfterGetRecord`: `TokenSet := Rec.HasToken()`. This is allowed by `bluace-page-code.md` Rule 1: "setting page variables … using values returned by table procedures". Each row gets its own value because it is set per record.
- Actions (with `actionref` in the `Promoted` area, because `NoPromotedActionProperties` is on):
  - `SetToken` (Caption 'Set Token', Image `EncryptionKeys`): `Rec.SetToken(); CurrPage.Update(false);`
  - `ClearToken` (Caption 'Clear Token', Image `Delete`): `Rec.ClearToken(); CurrPage.Update(false);`
- Tooltips on every field and action (UICop).

## Codeunit "Env. Trigger Subscr. GHP" (R4.1)

`Access = Internal`, folder `src/General` (`bluace-table-triggers.md` Rule 2).

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Environment Triggers", OnAfterCopyEnvironmentPerCompany, '', false, false)]
local procedure DeleteTokensOnAfterCopyEnvironmentPerCompany()
var
  BaseURL: Record "Base URL GHP";
begin
  BaseURL.DeleteAllTokens();
end;
```

Verified (symbols): Codeunit 2000000012 "Environment Triggers" in System 28.0.54846.0 has `OnAfterCopyEnvironmentPerCompany` (parameters SourceEnvironmentType, SourceEnvironmentName, DestinationEnvironmentType, DestinationEnvironmentName). The System Application subscribes in the same way (`Environment Cleanup/src/EnvironmentCleanupImpl.Codeunit.al:28-29`). The subscriber uses none of the parameters, so it omits them (implementation 2026-10-20); a subscriber that declares parameters must use the publisher's names (`bluace-compile.md` Rule 3).

## Test app (automated tests)

New project `GithubProjects.Test` (`al-testing.md` Rule 1, `bluace-testing.md`):
- `app.json`: id `07603d66-88b2-4335-9afc-67cf7c33776a`, name "GitHub Projects Test", publisher "Bluace BV", version 1.24.0.0, platform and application 28.0.0.0, runtime 17.0, `idRanges` 50000–50099, features `TranslationFile`, `NoImplicitWith`, `NoPromotedActionProperties`.
- Dependencies: GitHub Projects (`af681b8d-beb5-4d8f-b66a-5980d979c1c9`), "Library Assert", "Any", "Tests-TestLibraries", "Permissions Mock" (`40860557-a18d-42ad-aecb-22b7dd80dc80`, `bluace-testing.md` Rule 6). The IDs and versions of the Microsoft test apps are confirmed when the symbols are downloaded from the container. Their symbols are not yet in `.alpackages`.
- GithubProjects `app.json` `internalsVisibleTo` lists only the test app, so tests can call `SetToken(SecretText)`, `GetToken` and `DeleteAllTokens`.
- `.vscode/settings.json` and `launch.json` copied from GithubProjects (same analyzers, including `${PerTenantExtensionCop}`). `Translations/GitHub Projects Test.en-US.xlf` and `.nl-NL.xlf` (Rule 7).
- Permission set 50000 "Projects Test GHP" (`Assignable = false`): execute permission on the test codeunits, the library, Assert, Any, "Permissions Mock" and "Library - Lower Permissions". Permission tests add it after `SetExactPermissionSet`, because the exact set otherwise also removes execute permission on Codeunit Assert (seen at implementation 2026-10-20). It grants no table data.
- Symbols of the test toolkit (28.5.54151.54910) are downloaded from the container into `GithubProjects.Test/.alpackages`, including the indirect dependencies "System Application Test Library", "Application Test Library" and "Business Foundation Test Libraries". The IDs in `app.json` were confirmed from their manifests.

| Type | ID | Name | File | Folder | Acceptance |
| --- | --- | --- | --- | --- | --- |
| Codeunit | 50000 | UT Base URL GHP | UTBaseURL.Codeunit.al | src/BaseURL | A |
| Codeunit | 50001 | UT Base URL Token GHP | UTBaseURLToken.Codeunit.al | src/BaseURL | B |
| Codeunit | 50002 | UT Base URL Perm. GHP | UTBaseURLPerm.Codeunit.al | src/BaseURL | C |
| Codeunit | 50003 | UT Env. Copy GHP | UTEnvCopy.Codeunit.al | src/BaseURL | D |
| Codeunit | 50004 | UT Base URL UI GHP | UTBaseURLUI.Codeunit.al | src/BaseURL | E (TestPage; run in the AL Test Tool, because the AL MCP runner does not fail on unhandled dialogs) |
| Codeunit | 50005 | Library - Base URL GHP | LibraryBaseURL.Codeunit.al | src/Common | – |

- "Library - Base URL GHP": `CreateBaseURL(var BaseURL; SourceType)` with a random Code and URL `https://<random>.invalid` (Any). It uses the `.invalid` host as a backstop habit, although this feature sends nothing. It also has `SetDummyToken(var BaseURL)`, which uses `SecretStrSubstNo('dummy-%1', ...)` (`bluace-compile.md` Rule 3).
- **Asserting tokens:** the test app cannot read GithubProjects' Isolated Storage (module isolation), and `SecretText.Unwrap()` is on-premises only (Learn: *SecretText.Unwrap*). Tests therefore check `HasToken()` and `GetToken().IsEmpty()`. Whether a token is *replaced* by a different value can only be seen when the token is sent. Feature 2's mock handler proves that.
- **Delete test (B8):** after `Delete(true)`, re-insert a record with the same `SystemId` (`Insert(true, true)`) and assert `HasToken() = false`.
- **Permission tests** (C, `bluace-testing.md` Rule 3): create data first, `PermissionsMock.Start()`, `LibraryLowerPermissions.SetExactPermissionSet('Projects User GHP')` or `'Projects Admin GHP'` in the test procedure itself (CodeCop AA0087), and stop afterwards. Verified (source): `SetExactPermissionSet` in `Layers/W1/Tests/TestLibraries/LibraryLowerPermissions.Codeunit.al:377`.
- **Dialog in tests:** section E uses a `ModalPageHandler` on TestPage "Password Dialog" that sets field `Password` and chooses OK or Cancel (verified (source): field `Password`, `PasswordDialog.Page.al:35`). Sections A–D use the internal `SetToken(SecretText)` and need no page.
- **Confirmation:** `ConfirmHandler` with "Library Variable Storage" is not needed. Each test that confirms has its own handler (Yes or No).
- Expected messages are labels in the test codeunits with the app's exact English text and comment, asserted with `Assert.ExpectedError(StrSubstNo(...))` (Rule 7).

## Permission sets (R5)

| Name | Caption | Assignable | Contents | Who |
| --- | --- | --- | --- | --- |
| Projects User GHP | GitHub Projects - User | true | `tabledata "Base URL GHP" = R`, `table "Base URL GHP" = X`, `page "Base URLs GHP" = X`, `codeunit "Base URL Helper GHP" = X`, `codeunit "Env. Trigger Subscr. GHP" = X` | Every user who views the data (later features add their own objects) |
| Projects Admin GHP | GitHub Projects - Admin | true | `IncludedPermissionSets = "Projects User GHP"`; `tabledata "Base URL GHP" = RIMD` | Users who maintain base URLs and tokens |

The admin set is separate because whoever can change a base URL can redirect its token to another host (accepted risk in requirements.md). Codeunit "Env. Trigger Subscr. GHP" is in the user set because ApplicationCop AC0010 requires every object to be covered by a permission set (implementation 2026-10-20). It runs in the environment-copy session; M1 confirms that it works there.

Captions have `MaxLength = 30` (ApplicationCop AC0009: permission set captions must not exceed 30 characters in any translation).

## Traceability

| Requirement | Plan section |
| --- | --- |
| R1.1–R1.2 | Enum, Table, Page |
| R1.3–R1.6, R1.8 | Table triggers, Helper `ValidateUrl`/`CheckUrl` |
| R1.7 | Table (SystemId key), Helper `GetTokenKey` |
| R2.1–R2.3, R2.6 | Helper `SetToken`/`ClearToken`/`CheckSaved`, Page actions |
| R2.4–R2.5 | Page `TokenSet`, Table `HasToken` |
| R2.7 | Table `OnDelete`, Helper `DeleteToken` |
| R2.8–R2.9 | Helper `GetTokenKey` (SystemId), `DataScope::Company` |
| R2.10 | Table `GetToken` (internal), `internalsVisibleTo` |
| R3.1–R3.3 | Helper `CheckWritePermission`, Permission sets |
| R4.1 | Codeunit "Env. Trigger Subscr. GHP", Helper `DeleteAllTokens` |
| R5.1–R5.2 | Permission sets |
