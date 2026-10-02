# Releasing WindowsDeviceLink

WindowsDeviceLink uses a deliberately manual, release-driven publication process. A normal push to `main` must never publish a PowerShell Gallery package or create a GitHub release.

## Version source of truth

The module manifest is the source of truth:

```text
src/WindowsDeviceLink/WindowsDeviceLink.psd1
```

A preview such as `0.12.1-preview1` is represented by these manifest fields:

```powershell
@{
    ModuleVersion = '0.12.1'
    PrivateData = @{
        PSData = @{ Prerelease = 'preview1' }
    }
}
```

The corresponding GitHub tag is:

```text
v0.12.1-preview1
```

For a stable release, leave `Prerelease` empty/remove the prerelease label and use a tag such as `v1.0.0`.

## Release principles

- Releases are intentional and manually started.
- The version is derived from the manifest; workflow files do not hardcode a release number.
- The PowerShell Gallery package is built with `tools/New-GalleryPackage.ps1`.
- `Windows.Management.Service.dll` must never be redistributed in the Gallery package.
- Existing Gallery versions and GitHub release tags are immutable. Bump the version instead of replacing a release.
- `PSGALLERY_API_KEY` is stored only as a GitHub Actions secret.
- Code signing is planned separately. Until signing is implemented, the current WinPE publisher-check workaround is documented in `docs/INSTALLATION.md`.

## Pre-release checklist

Before publishing a new version:

1. update `ModuleVersion` and `PrivateData.PSData.Prerelease` in the manifest;
2. update release-facing documentation where the currently published version is mentioned;
3. run the Windows 11 smoke tests;
4. run the AMD64 WinPE smoke tests where applicable;
5. review [recorded evidence](../TESTING.md) and complete the applicable items in the
   [current validation checklist](VALIDATION-CHECKLIST.md), recording artifact version,
   execution date and environment for separate operator and automation paths;
6. scan the public repository for tenant IDs, serial numbers, association IDs, JWT data, secrets, test API keys and other environment-specific identifiers;
7. confirm `Windows.Management.Service.dll` is not present in the public repository or release package;
8. build locally with `tools/New-GalleryPackage.ps1` when doing a final manual verification;
9. verify the public command surface with `Test-ModuleManifest` / `Get-Command`;
10. require successful Module CI, including documentation checks, for the exact candidate;
11. commit all release content to `main` before starting either release workflow.

## Documentation checks

CI checks repository-local Markdown links and heading anchors, including links in
historical documents. It does not request external websites. Run the same check locally:

```powershell
python tests/Documentation-Links-Tests.py
python tests/Documentation-Links-Validation.py
```

The Windows PowerShell job also parses fenced PowerShell examples in current guides
and compares literal public command names, named parameters, parameter sets and
ValidateSet values with the staged module. It never executes the examples:

```powershell
.\tests\Documentation-Examples-Validation.ps1
```

Release notes, the historical 0.10 matrix and the archived 0.4.x lifecycle plan are
excluded from current-command checks. Keep new executable examples in `powershell`
fences and use full parameter names. Dynamic values, splatted arguments, permissions,
runtime behavior, diagram rendering and screenshot readability require separate review.

## Create the GitHub release and immutable tag

Use GitHub Actions -> **Create GitHub Release** -> **Run workflow**.

The optional `expected_version` input is a safety check. For example:

```text
0.12.1-preview1
```

The workflow derives `v<version>` from the manifest, verifies that the source is the current GitHub-Verified `main` commit, and creates the release/tag (marked prerelease only when the manifest has a prerelease label) without moving an existing tag.

When `docs/releases/<version>.md` exists, its curated notes are included before the
automatically generated change list. The immutable tag is required before Gallery publication.

## Publish to PowerShell Gallery

After the GitHub release/tag exists, use GitHub Actions -> **Publish PowerShell Gallery** -> **Run workflow** and provide the exact release version, for example:

```text
0.12.1-preview1
```

The Gallery workflow:

1. checks out the exact immutable `v<version>` tag;
2. verifies that HEAD matches that exact tag;
3. builds the staged Gallery package;
4. validates the manifest and public command surface;
5. runs hardware-independent regression checks against the staged artifact;
6. verifies that no Microsoft runtime DLL is bundled;
7. publishes with the `PSGALLERY_API_KEY` repository secret.

A normal push to `main` never publishes a Gallery package.

## Recommended order

1. Finish code and documentation.
2. Validate applicable Windows / WinPE paths and run CI.
3. Review the public repository and release package.
4. Merge the release-preparation PR through GitHub and verify the resulting main commit.
5. Run Create GitHub Release to create the immutable source tag.
6. Run Publish PowerShell Gallery for that exact tag.
7. Install the actual Gallery package and record the smoke-test result.

The GitHub release/tag is intentionally created before Gallery publication because the Gallery workflow publishes only from an immutable release tag.

## Signing roadmap

WindowsDeviceLink is currently unsigned. The planned supply-chain improvement is public Authenticode signing, preferably through SignPath Foundation, followed by verification in the release pipeline. Once signing is implemented, repeat the WinPE `Install-Module` test without `-SkipPublisherCheck` and update `docs/INSTALLATION.md` based on the result.
