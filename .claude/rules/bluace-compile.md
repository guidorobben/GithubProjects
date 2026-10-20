# Bluace: Compiling and Code Analysis

The apps must compile without warnings under the same analyzers and ruleset that VS Code uses (`.vscode/settings.json` of each app).

## Rule 1: Compile with the workspace analyzers and the Bluace ruleset

### Intent
Use `alc.exe` from the AL extension (`%USERPROFILE%\.vscode\extensions\ms-dynamics-smb.al-<version>\bin`) to get the real diagnostics. The AL MCP `al_build`/`al_compile`/`al_getdiagnostics` results are not reliable in this multi-project workspace: they can report objects of other projects as missing, or return no diagnostics at all.

Pass the same analyzers as `al.codeAnalyzers` in `.vscode/settings.json`:
- `${CodeCop}`, `${UICop}`, `${PerTenantExtensionCop}` (the `Microsoft.Dynamics.Nav.*Cop.dll` files in the extension's `bin` folder);
- `ALCops.ApplicationCop`, `ALCops.Common`, `ALCops.DocumentationCop`, `ALCops.FormattingCop`, `ALCops.LinterCop`, `ALCops.PlatformCop` (`ALCops.*.dll` in the same folder).

Pass the Bluace ruleset with `/ruleset:`. It is referenced by `al.ruleSetPath` in `.vscode/settings.json`; download it to a local file first. Without the ruleset many rules appear that the team has switched off (e.g. PC0037, AC0030, DC0004–DC0010, PTE0012).

Do not use AppSourceCop for these per-tenant extensions: its manifest and ID-range rules do not apply.

### Examples

```powershell
# Good example
$bin = (Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter 'ms-dynamics-smb.al-*' | Sort-Object Name | Select-Object -Last 1).FullName + '\bin'
$alc = (Get-ChildItem $bin -Recurse -Filter alc.exe | Select-Object -First 1).FullName
$analyzers = @(Get-ChildItem $bin -Recurse -Filter 'Microsoft.Dynamics.Nav.*Cop.dll' | Where-Object Name -match 'CodeCop|UICop|PerTenantExtensionCop' | Select-Object -Expand FullName -Unique)
$analyzers += 'ApplicationCop','Common','DocumentationCop','FormattingCop','LinterCop','PlatformCop' | ForEach-Object { "$bin\ALCops.$_.dll" }
$project = 'C:\Repository\GithubProjects\GithubProjects'
& $alc /project:"$project" /packagecachepath:"$project\.alpackages" /out:"$project\Bluace BV_GitHub Projects_1.24.0.0.app" `
    @($analyzers | ForEach-Object { "/analyzer:$_" }) /ruleset:"$env:TEMP\bluace-ruleset.json"
```

## Rule 2: Fix warnings; do not suppress them

### Intent
Fix the cause of a warning instead of hiding it. Do not use `#pragma warning disable`. If a rule cannot be met, ask the team instead of suppressing it.

## Rule 3: Language facts verified in BC 29

### Intent
These were verified by compiling or testing against BC 29 and save a round of trial and error:
- Pages cannot have the `Access` property (AL0124); only tables, codeunits, enums and similar objects can be `Access = Internal`.
- An interface can be a parameter of an event publisher, including `[InternalEvent]`.
- Converting `Text` to `SecretText` by assignment only compiles inside a `[NonDebuggable]` procedure; elsewhere use `SecretStrSubstNo(...)`.
- Event subscriber parameters bind by name, so they must use the publisher's names (e.g. `var Rec`).
- Moving a `Label` to another object changes its XLIFF trans-unit id: regenerate the translation files after such a move.
- CodeCop AA0072 compares variable names with the object name including the app suffix: `SetupMPTE: TestPage "Setup MPTE"` passes, `SetupPage` or `SetupTestPage` does not. For system types, end the name with the type (e.g. `NativeHttpRequestMessage: HttpRequestMessage`).
- ALCops AC0027 treats a `Locked = true` label without placeholders as a token: give it the `Tok` suffix, also when it is used in `Error(...)`.
