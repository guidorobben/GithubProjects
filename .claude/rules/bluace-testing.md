# Bluace: Automated Tests

Supplements `al-testing.md` with what applies to the test apps in this repo.

## Rule 1: Running tests with the AL MCP tools

### Intent
- Run tests with `al_run_tests` per test codeunit, with `projectPath` (the test app folder, so its `launch.json` is used) and `company: "CRONUS NL"`. Without them the runner gets a 401.
- The AL MCP test runner cannot run tests that use TestPages. Put TestPage scenarios in a separate UI test codeunit; they run in the AL-Go pipeline.
- The AL MCP test runner does not fail a test on an unhandled dialog (verified 2026-10-20 in GithubProjects: a test without a ConfirmHandler passed there and failed in the AL Test Tool with "Unhandled UI: Confirm"). A pass in the MCP runner does not prove that no dialog opened: confirm scenarios that check "no dialog" or rely on handlers in the AL Test Tool or the AL-Go pipeline.
- Publish the app and the test app first (see `bluace-dev-environment.md`).

## Rule 2: No external communication in tests

### Intent
Tests never call external services, in containers and in online sandboxes alike.
- Replace HTTP calls with a mock that implements the System Application Interface "Http Client Handler". Inject it through an `[InternalEvent]` in the app's API client, and expose internals to the test app with `internalsVisibleTo`.
- As backstops, point the base URL at an unresolvable `.invalid` host and use a dummy token.
- Do not use `TestHttpRequestPolicy`; it is on-premises only.

## Rule 3: Permission tests must start Permissions Mock

### Intent
"Library - Lower Permissions" does nothing unless Codeunit "Permissions Mock" is started, and the AL MCP test runner does not start it. A permission test would then pass without any restriction.
- Start it in the test (`if not PermissionsMock.IsStarted() then PermissionsMock.Start();`, e.g. through a test library procedure) and stop it again afterwards.
- Call "Library - Lower Permissions" (e.g. `SetO365BusFull()`, `AddPermissionSet(...)`) directly in the test procedure, not in a helper (CodeCop AA0087).
- Create test data before lowering permissions.

## Rule 4: asserterror rolls back uncommitted data

### Intent
`asserterror` rolls back every uncommitted change of the test, including test data created before it. Commit test data (with a comment explaining why) that the test checks or needs after an `asserterror`.

## Rule 5: Every test starts with its scenario and acceptance criterion

### Intent
The first line of every test procedure is a `[SCENARIO]` comment with the number of the acceptance criterion it covers (from the feature's `acceptance.md`) and a one-sentence description, followed by the `[GIVEN]`/`[WHEN]`/`[THEN]` comments. Prefix the test procedure name with the same number. When one test covers several criteria, list them all; when several tests cover one criterion, each repeats that number.

### Examples

```al
[Test]
procedure B7_ActiveLinkBlocksNewLink()
var
    // ...
begin
    // [SCENARIO B7] An active link is refreshed first and then blocks a new link.
    // [GIVEN] INV-A with an active link that is still active in Mollie
    // ...
    // [WHEN] A link is created
    // ...
    // [THEN] The link is refreshed first, then an error names the active link; no POST
end;
```

## Rule 6: Test app dependencies in BC 29

### Intent
In BC 29, "Tests-TestLibraries" does not pass on all libraries to the test app. Add these as direct dependencies when used: "Library Variable Storage" (`5095f467-0a01-4b99-99d1-9ff1237d286f`) and "Permissions Mock" (`40860557-a18d-42ad-aecb-22b7dd80dc80`), next to "Library Assert", "Any" and "Tests-TestLibraries".

## Rule 7: Tests must pass in every client language

### Intent
The app is translated (en-US, nl-NL), so error texts depend on the language of the user who runs the tests. Never assert on an English fragment of an app message.
- Declare the expected message in the test codeunit as a translatable label with the exact same English text as the app's label (same `Comment`), and assert the full message: `Assert.ExpectedError(StrSubstNo(PaidLinkCannotBeArchivedErr, LinkId))`.
- The test app has a dedicated XLIFF file for every language the app supports, named like the app's files: `Translations/<test app>.<language>.xlf` (e.g. `Mollie Integration.Test.en-US.xlf`, `Mollie Integration.Test.nl-NL.xlf`). When the app gets a new language, add the matching file to the test app too.
- Every label in the test app gets a target in each of these files, copied from the app's translation of the same source text in that language.
- Build captions in the message with `FieldCaption(...)`, not literals.
- Fragments that are language-independent (HTTP status codes, URLs, texts returned by the mock) may stay literal.

## Rule 8: Test codeunit names start with UT

### Intent
Every codeunit with `Subtype = Test` has a name that starts with `UT `, followed by the feature or object it tests and the app suffix. Its file name starts with `UT` too (`<ObjectNameWithoutSuffix>.Codeunit.al`). This keeps test codeunits recognisable and sorted together.
- Every UT codeunit sets `TestPermissions = Disabled;` right after `Subtype = Test;`. Permission scenarios lower permissions explicitly with "Permissions Mock" and "Library - Lower Permissions" (Rule 3).
- Do not add "Tests" to the name; `UT` already says it.
- Libraries, mocks and other helper codeunits of the test app are not test codeunits and keep their own names (e.g. "Library - Gen. Journal PTE", "Mock Http Handler MPTE").
- Stay within the 30-character limit, abbreviating the middle part when needed.
- Renaming an object changes the XLIFF trans-unit ids of its labels (`Codeunit <hash of name> - NamedType ...`). Update the ids in every translation file of the test app, or regenerate them, so no translation is lost.

### Examples

```al
// Good example
codeunit 80000 "UT Invoice Report PTE"          // UTInvoiceReport.Codeunit.al
codeunit 80001 "UT Wage Journal Import PTE"     // UTWageJournalImport.Codeunit.al
codeunit 80002 "UT Wage Journal Import UI PTE"  // UTWageJournalImportUI.Codeunit.al
```

```al
// Bad example (avoid names without the UT prefix)
codeunit 80000 "Invoice Report Tests PTE"
```
