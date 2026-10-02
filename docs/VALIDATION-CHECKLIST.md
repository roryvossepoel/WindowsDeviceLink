# Current validation and polish checklist

Reviewed: 2026-10-02 after stable publication and the live Windows 11 AMD64 Gallery smoke test.
Current published and live-tested stable Gallery package: `1.0.0`.

This checklist separates current passes, earlier evidence, remaining live checks and
optional polish. [TESTING.md](../TESTING.md#published-0121-preview1-windows-11-amd64-validation)
records the tested artifact, source commit, environment and observed results. Earlier
passes remain tied to their recorded versions; they are not relabeled as new tests.
The 0.10 matrix and 0.4.x lifecycle plan are historical documents.

The agreed route toward stable is: record completed tests, retain the completed Direct
Configuration checks and earlier authentication evidence, correct release-facing documentation, then validate and publish
the final package. Do not repeat full Backend, ARM64 or WinPE lifecycles unless a
relevant change or a concrete regression warrants it. Unknown or untested behavior is
not marked Pass merely because the release scope has been narrowed.

## 1. Direct on Windows 11

**Status: Core GUI/CLI, configuration loading, tenant switching and sign-out checks passed; earlier app-authentication evidence retained.**

The first single-tenant inline check found a real 0.12.1-preview1 defect: the fixed
tenant was displayed as "Determined by sign-in". The array-normalization correction
passed CI and a live fixed-tenant sign-in/lookup/sign-out check on source commit
`3aa88cc4d570cb48e50e366a3c240d9cd41e634d` (not the Gallery preview).
The two-tenant check then found that sign-out left the selector disabled. The fix
restores the idle UI state; its regression check covers Interactive and DeviceCode.
Second-tenant sign-in/lookup passed with the earlier-build workaround, and source commit
`f5f99633ca25c8fe58db5f04f6d6de865f6c5890` passed the live immediate-unlock check.
The subsequent change clears the cached cloud status and cloud card on sign-out;
its live Interactive display check passed on source commit
`b1861088304bdbab3d47450f36508065676188af`. The final requested refinement resets a
multi-tenant selection to the placeholder on sign-out (fixed single tenants remain);
its live Interactive and DeviceCode sign-out checks passed on source commit
`de82a23e87b1256c7a3ccead6cc36e1c7779bc78`. These fixes are not yet in the Gallery preview.
The same source passed inline/local-file/HTTPS loading and an Interactive tenant switch
after a Windows restart. Earlier intermittent authentication failures and a passkey-page
error are recorded in TESTING.md; their root cause remains unproven.

- [x] GUI Interactive: sign in, cancel/retry, cloud refresh, session reuse and sign out/in.
- [x] GUI DeviceCode: sign in, cloud refresh, session reuse and sign out/in.
- [x] Default GUI sign-in tenant and explicit-tenant Interactive CLI lookup.
- [x] GUI pre-association, completion, cloud-only removal and local/full offboarding.
- [x] CLI registration, verified completion, repeated-completion no-op, cloud removal,
  local reset, repeated-reset no-op and new base identity generation.
- [x] GUI CSV export while signed out (operator-reported pass).

The following tracks focused configuration checks, using read-only cloud refresh
where possible. There is no need to repeat registration or tenant Move to validate
selection and authentication routing.

- [x] Load Direct configuration from a local JSON file, inline JSON and trusted HTTPS.
  A load/display check is sufficient for each source; do not repeat a lifecycle per source.
- [x] One configured tenant: correct fixed name before sign-in, after sign-in and after
  sign-out; authentication and cloud lookup target that tenant.
- [x] Multiple configured tenants: select, sign in and refresh; sign out, switch tenant,
  sign in and refresh; verify the new session/lookup tenant and cleared prior cloud context.
- [x] Final multi-tenant sign-out behavior with Interactive and DeviceCode: account
  cleared, cloud card Not checked, selector unlocked and reset to its placeholder.
- [x] Retain earlier operator-reported own-app/certificate authentication tests and
  automated shared/per-tenant clientId routing coverage; no blanket authentication rerun.

The exact shared/per-tenant Direct JSON custom-app combinations were not separately
re-established live in this follow-up. An additional live routing check is deferred
unless a relevant change or concrete regression warrants it, not marked as a new Pass
and not a stable gate. Certificate app-only tests do not alone prove delegated GUI routing.

JSON/schema validation, duplicate names/IDs, invalid/conflicting inputs, clientId
precedence and authentication parameter routing already have automated coverage in
`Configuration-Validation.ps1`. Do not treat those mocked checks as live GUI passes.
Direct checks one selected tenant per operation; cross-tenant Move belongs to Backend.

## 2. Direct on AMD64 Windows PE

**Status: Earlier runtime/Direct evidence retained; no blanket rerun for stable.**

Earlier live results cover BYO-DLL activation, identity, firmware, DeviceCode operations,
pre-association/removal and published-package use. Earlier WinPE GUI lifecycle results
also cover Backend assignment, offboarding and CSV export. See [TESTING.md](../TESTING.md).
These are distinct routes and must not be conflated.

The new Direct Configuration selector and the 0.12.1 signed-out Direct GUI reset have
not received a new live WinPE run. They remain identified compatibility coverage gaps;
mocked configuration/GUI tests cover their parameter routing and WinPE guards. Per the
agreed release scope, a complete WinPE lifecycle rerun is deferred unless relevant code
changes or evidence of a regression arise.

Retest the affected route after changes to the DLL loader, architecture/environment
detection, WinPE authentication or firmware behavior. The supported WinPE workflow
uses an administrator-supplied compatible DLL. Native completion belongs to full
Windows/OOBE; ARM64 WinPE remains unsupported.

## 3. Operator UI review

**Status: Changed recovery dialogs checked; remaining work is targeted usability polish.**

- [x] Administrator guidance before dashboard startup (pre-publication source candidate).
- [x] Local-only warning shown in default Interactive and explicit DeviceCode GUI modes.
- [x] Reset cancellation leaves state unchanged (pre-publication source candidate).
- [x] Signed-out DeviceCode reset from 4/4 and default Interactive reset from 2/4 succeed
  without cloud authentication; local refresh can generate a new base identity.
- [x] GUI contract tests cover default No, Backend cloud-known-absent gating,
  cancellation, busy state and failure paths on the tested release commit.
- [x] Complete the configured tenant/account display and switching checks in section 1.
- [ ] Broader visual polish: 1366x768 and 100/125/150/200% scaling, long names/errors,
  keyboard focus/tab order and Copy activity behavior.

The screenshots do not independently prove the default keyboard focus. Offline
Interactive reset starting at 4/4 was not separately exercised in this run; do not
expand the recorded 2/4 pass into that claim. Broader UI review is not a requirement to
repeat every lifecycle. Fix any observed issue that makes controls unreachable or
misrepresents the selected tenant/local/cloud scope.

## 4. Failure handling and targeted Backend regression

**Status: Earlier Backend lifecycle evidence and automated safety coverage retained.**

Backend catalog, New/no-op, bidirectional Move and offboarding have earlier physical
validation. Isolated per-tenant certificate/client-secret profiles have mocked coverage;
this does not imply every credential profile was tested live.

Automated tests cover failed Graph lookup classification as Unknown, unsafe-action
blocking, backend ambiguity, timeout parameter propagation and uncertain-write recovery
requiring a fresh lookup. Interactive cancel/retry was tested live in the current GUI.

Remaining live coverage gaps are DeviceCode expiry, denied permissions and network
interruption. Keep them unclaimed. They are additional targeted hardening checks, not
an instruction to rerun all historical authentication and Backend combinations before
stable. Exercise them if a relevant code change or concrete finding warrants it.

Unattended Backend catalog/status/assignment/removal should likewise only receive a new
live regression run after changes affecting those paths. CLI contract tests cover
parameter forwarding and supported confirmation behavior; they are not live Azure runs.

Device Association cleanup does not itself end MDM enrollment; follow [offboarding](OFFBOARDING.md).

## 5. Deployment chain through OOBE

**Status: Earlier Windows/OOBE and WinPE evidence retained; no new full deployment run required.**

Do not infer completed Intune enrollment or application delivery from Associated alone.
A consolidated new WinPE-to-OOBE run and a specifically recorded v1/v2 coexistence
transition remain additional evidence opportunities, not newly imposed gates for an
unchanged deployment route. The [migration FAQ](FAQ.md#do-i-need-to-delete-the-autopilot-v1-object-before-transitioning-to-device-preparation)
describes the intended transition; it is not itself a physical test report.

## 6. Package and release verification

**Status: Stable 1.0.0 published and its actual Gallery package smoke-tested.**

- [x] Module CI passed for preview source `8237dda9fc9ed517a1dcccd43ca64fdf4159d256`.
- [x] GitHub release and Gallery workflows passed for the same immutable preview source.
- [x] Actual Gallery package 0.12.1-preview1 installed/imported on Windows 11 AMD64;
  GUI startup, local status and cloud operations passed.
- [x] Today's live results and their limitations recorded in TESTING.md.
- [x] Prepare the 1.0.0 stable manifest/version, release notes and current installation guidance.
- [x] Run CI, including documentation/package checks, against exact final stable commit
  `d9aa44fb3cb2418474832b355df8c95720c80e6e`.
- [x] Review the final public changes/package for environment identifiers, credentials,
  raw identity/JWT content and excluded Microsoft runtime binaries.
- [x] Publish immutable stable GitHub release/tag `v1.0.0` and matching Gallery artifact.
- [x] Perform an actual stable Gallery 1.0.0 install/import/version and GUI-startup check;
  the title showed WindowsDeviceLink 1.0.0 without Preview.

Do not republish unchanged module code solely for documentation updates. Earlier ARM64
and WinPE evidence remains in TESTING.md; no complete lifecycle rerun is required for a
version-label change. Retest WinPE installation without its documented unsigned-package
workaround only when the signing situation changes. See [RELEASING.md](RELEASING.md).

## 7. Final screenshots and documentation pass

**Status: Two sanitized examples published; additional images are non-blocking polish.**

- [x] README Backend GUI overview with a caption.
- [x] README PowerShell CLI status example with a caption explaining NotAssociated.
- [ ] Direct GUI with a generic multiple-tenant selector and signed-in context.
- [ ] Pre-associated and Associated states with accurate local/cloud labels.
- [ ] AMD64 WinPE pre-association with Associate unavailable.
- [ ] Use additional offboarding/CSV/Move images only where they clarify a procedure.
- [ ] Review identifiers, title bars, logs, paths and background windows before publication.
- [ ] Check images and Mermaid diagrams at normal GitHub width and on a narrow screen.

Done when images match the final UI and each relevant guide uses a small, readable set.
Track image delivery in [issue #20](https://github.com/roryvossepoel/WindowsDeviceLink/issues/20).

## Recording a test result

For each completed block, append a sanitized record here or link to a public test report:

| Field | Record |
|---|---|
| Checklist item / cases | Number and the exact scenarios exercised |
| Date | Actual execution date |
| Artifact | Module version, source commit and source/candidate/Gallery origin |
| Environment | Windows/WinPE build, AMD64/ARM64, native PowerShell version, runtime DLL version when applicable |
| Route | CLI/GUI, Direct/Backend, authentication and configuration source |
| Before / expected / observed | Local and cloud state, result decision and verification |
| Result | Pass, Fail or Blocked, with a sanitized evidence link and follow-up |

Leave untested combinations unchecked or explicitly identified as deferred; deferred is not Pass. Do not retain real tenant/user/device identifiers,
API keys, device codes, raw JWTs or DeviceLink payloads in public evidence.

## Separate follow-up projects

These remain outside the current polish/test checklist:

- [GitHub Pages documentation site (#48)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/48).
- [Deploy to Azure validation (#43)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/43).
- [Optional device preparation policy selection (#47)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/47).
- [Trusted code signing (#3)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/3), currently dependent on obtaining a trusted signing path.
- [Official WinPE runtime acquisition (#2)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/2) and [serial lookup performance (#1)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/1).
