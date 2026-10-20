# Bluace: Local Development Environment

How the local Business Central container is set up for this repo, and how to build and publish the apps to it with the AL MCP tools.

## Rule 1: The local container

### Intent
GithubProjects uses the existing container `tm2023w2v2-nl` (launch configuration "tm2023w2v2-nl" in `GithubProjects/.vscode/launch.json`).

- Despite its name, the container runs BC 28.5 NL: Application 28.5.54151.54910 and System 28.0.54846.0 (verified 2026-10-20 by downloading symbols from it). These match `GithubProjects/.alpackages` and the app's `application` 28.0.
- Development endpoint: server `http://tm2023w2v2-nl`, instance `BC`, port `7049`, tenant `default`, authentication `UserPassword`, `environmentType: OnPrem`. The company is not fixed in launch.json; pass it explicitly where a tool needs it.
- Symbols can be downloaded from `http://tm2023w2v2-nl:7049/BC/dev/packages?publisher=Microsoft&appName=<app>&versionText=28.0.0.0&tenant=default` with basic authentication.
- The repo has no AL-Go setup yet. The Bluace convention for a dedicated container is `.AL-Go/Bluace-DevEnv.ps1`, which calls AL-Go's `localDevEnv.ps1` and compiles and publishes all apps in `appFolders` and `testFolders` of `.AL-Go/settings.json`.

## Rule 2: Test libraries come from AL-Go settings, not from container flags

### Intent
AL-Go installs the test toolkit based on the test app's dependencies: a dependency on "Tests-TestLibraries" sets `installTestLibraries`; `"installTestLibraries": true` in `.AL-Go/settings.json` makes it explicit. Do not add test toolkit flags to `.AL-Go/NewBcContainer.ps1`: `$parameters.additionalParameters` are passed to `docker run`, so a flag such as `--includeTestLibrariesOnly` breaks container creation.

## Rule 3: Login for the AL MCP tools

### Intent
The AL MCP server authenticates with `UserPassword` only through the environment variables `BC_SERVER_USERNAME` and `BC_SERVER_PASSWORD`. `altool auth login` only supports Entra ID and cannot store an on-premises login.

- Put both variables in the `env` block of a `settings.local.json` (gitignored through `**/.claude/settings.local.json`). Never commit them.
- The file must be in the `.claude` folder of the folder where the Claude Code session starts. In VS Code with `al.code-workspace`, the session starts in the first workspace folder, which is `.claude` itself, so the file is `.claude/.claude/settings.local.json`.
- Settings are read when the session starts: restart Claude Code after changing them.
- If the AL MCP tools report "Authentication required", first check that `$env:BC_SERVER_USERNAME` is set in the session.

## Rule 4: Building and publishing with the AL MCP tools

### Intent
- Add every project with `al_addproject` (GithubProjects, GithubProjects.Test).
- Build and publish one project at a time; `al_build` with `scope: all` only builds the first project.
- Publish in dependency order: GithubProjects → GithubProjects.Test.
- `al_publish` parameters for the container: the development endpoint from Rule 1, with `authentication: UserPassword` and `environmentType: OnPrem`. To publish a package built with `alc.exe` (see `bluace-compile.md`), pass `appPath` with `skipBuild: true`.
- A dependent project needs the current symbols of its dependency: copy the freshly built `.app` into the dependent project's `.alpackages`, or download symbols from the container.
