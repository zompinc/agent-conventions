---
name: zomp-dotnet
description: Zomp conventions for .NET and C# work - stack defaults (Avalonia, CommunityToolkit.Mvvm, Serilog, TUnit), global usings, clean-architecture layering, Nerdbank.GitVersioning, central package management, PolySharp for down-level targets, and analyzer/build-quality rules. Load this before making stack, architecture, packaging, testing-framework, versioning, or build-configuration decisions in any C#/.NET repository, and before creating a new .NET project or csproj.
---

# Zomp .NET conventions

These extend the global conventions in `AGENTS.md`, which stay in force. Where this file is silent, the global rules apply.

## Stack defaults

- **Language**: C# on .NET, `LangVersion: preview`, `Nullable: enable`, `ImplicitUsings: enable`
- **UI**: Avalonia (cross-platform desktop + Android); never WPF or WinForms
- **MVVM**: CommunityToolkit.Mvvm (`[ObservableProperty]`, `[RelayCommand]`)
- **Logging**: Serilog in the entry-point project; all other layers use `ILogger<T>` from `Microsoft.Extensions.Logging.Abstractions` only
- **Testing**: TUnit + NSubstitute + FluentAssertions

### Testing packages

Two traps that every new test project hits, because the stack defaults above mandate the packages that spring them.

**Pin FluentAssertions to the 7.x line** (`7.2.2` or later 7.x). Version 8.0 moved to the Xceed commercial licence, which requires a paid per-developer licence for commercial use - and Zomp builds software for clients, so every use is commercial. 7.x remains Apache-2.0. A project that resolves "latest" lands on 8.x silently: there is no build warning, no restore error, nothing until someone reads the licence. Pin it explicitly in `Directory.Packages.props` with a comment saying why, so the next person does not "helpfully" bump it.

**TUnit needs the Microsoft.Testing.Platform opt-in in `global.json`** - not `dotnet.config`, which looks plausible and does nothing:

```json
{
  "test": {
    "runner": "Microsoft.Testing.Platform"
  }
}
```

The .NET 10 SDK stopped bridging MTP test projects through VSTest, so without this `dotnet test` fails with "Testing with VSTest target is no longer supported by Microsoft.Testing.Platform on .NET 10 SDK and later". `TestingPlatformDotnetTestSupport` is the old bridge and should be removed rather than added. Separately: `dotnet test --nologo` forwards `--nologo` to the test application, which rejects it with exit code 5 and reports "Zero tests ran" - drop the flag rather than debugging the exit code.

### Global usings

Declare common namespaces once per project in the `.csproj` (or a `GlobalUsings.cs` if you prefer one place across the solution) - not at the top of every file. New projects must do this from the first commit.

```xml
<ItemGroup>
  <Using Include="System.Globalization" />
  <Using Include="Microsoft.Extensions.Logging" />
  <Using Include="CommunityToolkit.Mvvm.ComponentModel" />
  <Using Include="CommunityToolkit.Mvvm.Input" />
  <!-- project-local domain namespaces -->
  <Using Include="MyApp.Domain.Models" />
  <Using Include="MyApp.Domain.Abstractions" />
</ItemGroup>
```

Rules of thumb:

- **The target is zero file-level `using` directives**, not a threshold. An earlier version of this rule said "globalise anything referenced in more than ~3 files", which sounds reasonable and is worse in practice: it needs a per-namespace file count nobody will actually run, it leaves a residue that looks like an unfinished sweep, and it puts the convention permanently at odds with the analyser below. "No file-level usings" is checkable in one grep: `grep -rn "^using " --include=*.cs src tests tools`.
- Per-project, not global-across-solution - Domain, Application, Infrastructure, and UI projects each have distinct natural sets.
- Test projects also get global usings (`TUnit.Core`, `FluentAssertions`, the SUT's domain models).
- Don't `Include` a namespace that's already in the SDK's default implicit-usings set. **Check rather than recall it**: the set is written to `artifacts/obj/<Project>/<config>_<tfm>/<Project>.GlobalUsings.g.cs`, and it is wider than most people remember - `System.Collections.Generic`, `System.IO`, `System.Threading` and `System.Threading.Tasks` are all in it. Namespaces that look like the strongest globalisation candidates are usually already covered, so the file-level lines are redundancy to delete rather than globals to add.
- **Aliases can be global too.** `<Using Include="System.Threading.Tasks.Task" Alias="Task" />` emits `global using Task = System.Threading.Tasks.Task;`. Worth knowing where a name genuinely collides - `Microsoft.VisualStudio.Shell` defines its own `Task`, so a VSIX head would otherwise restate the alias at the top of every file that awaits anything.
- **Adding the `<Using>` is only half the change.** Delete the now-redundant file-level `using` lines in the same commit. Declaring a global and leaving the per-file copies in place is the most common way this convention rots: the project looks compliant from the csproj, while every file still repeats what is already global. A project can sit like that for months because nothing fails - the duplicates are legal C# and the build stays clean.

### Enforcing it

A one-time sweep does not hold. Turn the drift into a build break:

```ini
# .editorconfig
dotnet_diagnostic.IDE0005.severity = error
```

`IDE0005` needs `GenerateDocumentationFile` set to build cleanly, which the build-quality rules below already require. It catches what a namespace-by-namespace sweep structurally cannot: a using that is unnecessary for some reason other than being global - an alias with nothing left to disambiguate against, or a namespace that was never used in the first place.

One caution when scripting a sweep: in a project using top-level statements, `using var x = new Thing();` sits at column zero and reads exactly like a directive. It is a using *statement*, and removing it changes when the object is disposed. Match on `^using [\w.]+;$` so a line containing `=` can never be caught.

### Retrofitting an existing project

Worth doing, and safe if scripted rather than hand-edited:

1. Commit or stash first. This touches every file in the project, so `git restore` must be a real escape hatch.
1. Inventory before deciding: count how many files reference each namespace per project, and list what the csproj already declares. The two sets rarely match.
1. Apply per project, not per solution - each layer has a different natural set.
1. Strip only exact `using X;` lines. Leave `using static` and aliases alone.
1. Remove any leading blank line a fully-stripped file is left with, or StyleCop SA1517 fails the build.
1. Build and run the tests before committing. Ambiguity between two newly-global namespaces shows up as a compile error, not a silent behaviour change, so a clean build is a real signal here.

Reference sweep: `Zomp.Receipts`, 205 `using` lines removed across 76 files, of which the large majority were duplicates of globals the projects had already declared.

## Architecture pattern

```text
Domain          <- pure models and interfaces, zero dependencies
Application     <- ViewModels, depends on Domain only
Infrastructure  <- I/O, persistence; depends on Domain
UI              <- views, DI wiring; depends on all three
```

- ViewModels live in **Application** and must not reference any Avalonia type.
- Interfaces live in **Domain**. Implementations live in **Infrastructure** or **UI**.
- DI registration lives in the UI entry-point only.

## Versioning

Every deployable project derives its version from git, never hardcoded, and surfaces it somewhere a deployed environment can be asked. In .NET that means:

- Always use **Nerdbank.GitVersioning** (`Nerdbank.GitVersioning`, `PrivateAssets="all"`).
- Place `version.json` at the repo root; start new projects at `"version": "1.0-alpha"`.
- Never hardcode `ApplicationVersion`, `ApplicationDisplayVersion`, or assembly version attributes - NBGV manages all of these from git height.
- Display `ThisAssembly.AssemblyInformationalVersion` in the window title or About dialog.

## NuGet / package management

- Use **Central Package Management**: all versions in `Directory.Packages.props`.
- Never add `Version="..."` to a `<PackageReference>` in a `.csproj`.
- Analyzers and build tools use `PrivateAssets="all"`.
- **A `nuget.config` with package source mapping is required, not optional.** Central package management fails the build with NU1507 the moment more than one feed is configured, and Zomp machines carry nuget.org, the Zomp GitHub feed, and usually dotnet-tools. Map `*` to nuget.org and `Zomp.*` to the GitHub feed. This is a first-commit item: without it, the very first `dotnet build` in a new repo errors out.
- **Multi-targeting to `net472` or `netstandard2.0`: use PolySharp** (`PrivateAssets="all"` in `Directory.Build.props`), never hand-written polyfill files. Those targets lack the compiler-support types behind `init`, records, `required`, `System.Index` / `System.Range`, and the nullability attributes. The types are internal, so one shared copy cannot serve several projects - a hand-rolled file has to be linked into every net472 target, and it trips SA1402, SA1403, SA1649 and IDE0161 on the way, each needing its own `.editorconfig` exemption. PolySharp generates them per assembly on demand and emits nothing where the framework already supplies them, so it is safe to reference unconditionally. It is a no-op on modern-TFM-only projects, which is most Zomp work.

## Build output

Every repo uses the SDK's artifacts layout: one `artifacts/` tree at the repo root, never `bin/` and `obj/` scattered through each project.

```xml
<!-- Directory.Build.props, from the first commit -->
<PropertyGroup>
  <UseArtifactsOutput>true</UseArtifactsOutput>
</PropertyGroup>
```

- **It must be set in `Directory.Build.props`** (or on the command line), never in a `.csproj`. Output paths are computed before project files are evaluated, so the SDK rejects it outright with `NETSDK1199`. `ArtifactsPath` has the same restriction; set it only if the default location is wrong.
- Layout is `artifacts/{bin,obj,publish,package}/<ProjectName>/<config>[_<tfm>][_<rid>]/`. Multi-targeted projects get one folder per TFM (`debug_net472`, `debug_net10.0`); single-target projects get just `debug`.
- `.gitignore` needs `artifacts/`. Keep the `[Bb]in/` and `[Oo]bj/` patterns too, so stray output from a project that somehow escapes the layout is still ignored.
- **The config folder is lowercase** (`debug`, `release`). This is the same behaviour called out under Cross-platform CI below, and it is the single thing most likely to bite: a hardcoded `artifacts/bin/Foo/Release/` path works on Windows and fails on Linux CI.
- Verified compatible with VSIX projects built through `Microsoft.VSSDK.BuildTools`; the `.vsix` lands in `artifacts/bin/<Project>/<config>/` like any other output.

Why: a single ignorable tree makes cleaning one `rm -rf artifacts`, keeps CI artifact collection to one path, stops `obj/` from polluting file searches and editor indexing, and puts every project's output somewhere predictable instead of somewhere relative to the project file.

## Build quality

- `TreatWarningsAsErrors: true` - a build that doesn't pass clean is wrong.
- Roslynator.Analyzers + StyleCop.Analyzers.Unstable as global build-only references.
- `AnalysisMode: AllEnabledByDefault` - suppress with documented reasons in `.editorconfig`, not `#pragma`.
- SA1623: XML doc summaries on properties must start with "Gets" or "Gets or sets".
- CA1819: never return arrays from properties - use `IReadOnlyList<T>` or `IEnumerable<T>`.

## Cross-platform CI

- The SDK lowercases the `$(Configuration)` folder name in build output paths (`release` instead of `Release`) - see Build output above. This is invisible on Windows (case-insensitive FS) but breaks on Linux CI. When referencing build output paths across projects (e.g., in a Pack project), explicitly set `-p:OutputPath=...` with the correct casing rather than relying on `BaseOutputPath` + SDK-computed configuration subfolder.

## Repo-level exemptions

A repo's own `AGENTS.md` overrides these defaults, and a pre-existing project can be exempt from any of them - a WPF application that predates the Avalonia rule, say. The repo's file names its own exemptions and wins where the two disagree. Do not migrate such a project onto these conventions, or restructure it toward the architecture pattern above, without an explicit request.
