# WindowsDeviceLink validation matrix

Last updated: 2026-10-02

This file preserves recorded validation evidence, including results from earlier previews.
An earlier Pass does not certify every later package, authentication route or hardware build.
The current stable release is `1.0.0`; use the [current validation and polish checklist](docs/VALIDATION-CHECKLIST.md)
for follow-up polish and deferred coverage. A documentation review does not count as a live test.

## Current evidence summary

| Area | Recorded evidence | Remaining current-run evidence |
|---|---|---|
| Automated regression | Module CI and both release workflows passed for stable source `d9aa44fb3cb2418474832b355df8c95720c80e6e` | Retest affected paths after relevant changes |
| Backend on Windows 11 AMD64 / ARM64 and AMD64 WinPE | Physical-device lifecycle tests recorded below; ARM64 completion uses full Windows | Retest affected paths only after relevant changes; no blanket lifecycle rerun for stable |
| Direct CLI / GUI | Preview lifecycle checks and subsequent source-build tenant switching/sign-out checks passed on 2026-10-02; see the run record below | Earlier app-authentication evidence retained; wider failure/UI coverage remains separately identified |
| Direct JSON configuration | Inline, local file and HTTPS loading passed live; fixed-name, tenant switching and final sign-out behavior validated on source builds | Shared/overridden client routing covered offline; no blanket live authentication rerun |
| Published Gallery installation | Actual stable 1.0.0 Gallery install/import and GUI startup passed on Windows 11 AMD64 | Broader stable lifecycle repetition is not required |

## Published 1.0.0 Windows 11 AMD64 smoke test

Execution date: **2026-10-02**. The operator installed and imported the actual stable
PowerShell Gallery package `1.0.0` on the same physical Windows 11 AMD64 Surface Laptop 3
used for the focused release validation. The module opened successfully and the window
title displayed **WindowsDeviceLink 1.0.0** without the Preview label. Initial local
refresh completed with the expected base identity `2/4`; Direct Interactive was signed
out and the cloud card correctly showed Not checked.

The screenshot used for confirmation contains device identifiers and remains private.
No new cloud authentication, registration, removal or firmware mutation was performed
for this final package smoke test. Those behaviors retain the evidence recorded below.

| Release evidence | Result |
|---|---|
| Stable source and tag | GitHub-verified main commit `d9aa44fb3cb2418474832b355df8c95720c80e6e`; immutable tag `v1.0.0` |
| Module CI | Passed on the exact final main commit |
| GitHub release | Published as stable, not prerelease |
| PowerShell Gallery | Version `1.0.0` published with `IsPrerelease=False` |
| Actual Gallery package | Installed/imported successfully; GUI startup and stable title verified |

## Published 0.12.1-preview1 Windows 11 AMD64 validation

Execution date: **2026-10-02**. These results consolidate operator-provided screenshots,
CLI output and explicit pass confirmations from the live session. They are not tests
executed by the documentation editor. Private screenshots, payloads and device/tenant
identifiers are deliberately not copied into this public record.

| Field | Evidence |
|---|---|
| Artifact | Actual PowerShell Gallery package `0.12.1-preview1`; manifest version `0.12.1` |
| Source | `8237dda9fc9ed517a1dcccd43ca64fdf4159d256`, tag `v0.12.1-preview1` |
| Device | Physical Microsoft Surface Laptop 3, Windows 11 AMD64 |
| Host | Native Windows PowerShell 5.1, elevated for firmware operations |
| Runtime | System `Windows.Management.Service.dll`, version `10.0.26100.8875`, `RegisteredWinRT` |
| OS build | Not separately captured in this consolidated run record; the DLL version is not the OS build |
| Routes | Direct GUI Interactive and DeviceCode; Direct CLI local and explicit-tenant Interactive |
| Automated gates | [Module CI](https://github.com/roryvossepoel/WindowsDeviceLink/actions/runs/36975196204), [GitHub release](https://github.com/roryvossepoel/WindowsDeviceLink/actions/runs/36979932843), [Gallery publication](https://github.com/roryvossepoel/WindowsDeviceLink/actions/runs/36980090659): success on this source commit |

### GUI results

- Gallery installation/import and GUI startup with the expected preview version passed.
- Interactive sign-in, cloud refresh, session reuse, sign-out/re-sign-in and cancelled
  sign-in followed by a successful retry passed.
- DeviceCode sign-in, cloud refresh, session reuse and sign-out/re-sign-in passed.
  DeviceCode expiry was not exercised in this run.
- DeviceCode pre-association produced cloud `preassociated` with local base firmware
  `2/4`; completion produced cloud `associated` and local firmware `4/4` with the same
  cloud Association ID.
- Cloud-only removal succeeded; a separate refresh confirmed absence while local
  associated firmware remained `4/4`.
- Signed-out DeviceCode local reset, without a cloud check, showed the warning and
  changed `4/4` to a new base `2/4` identity after local refresh.
- Default `Show-WindowsDeviceLink` (Interactive, signed out) showed the local-only
  warning and reset an existing `2/4` identity to a new `2/4` identity after refresh.
  A separate offline Interactive `4/4` source-state test is not claimed here.
- The operator also confirmed direct Associate from base identity, combined
  offboarding, and CSV export while signed out. Those cases were reported as passed;
  their raw outputs are not retained in this record.

The administrator guidance and reset cancellation behavior were visually/operator
validated earlier in the same session on the source candidate before Gallery
publication. Default **No**, cancellation, failed reset, busy-state handling and
Backend cloud-known-absent gating also have automated GUI contract coverage. The
default keyboard focus was not independently established by the screenshots.

### CLI results

| Scenario | Observed result |
|---|---|
| Local identity and status | Same Link ID as GUI; base `2/4`; `CloudChecked=False`; no identity/firmware errors |
| Explicit-tenant Interactive status | `CloudChecked=True`, `AssociationPresent=False`, `NotAssociated`; repeated query reused the session |
| `Register-WindowsDeviceLink` | Registration returned `preassociated`; independent status lookup returned the same Association ID; local state stayed `2/4` |
| `Complete-WindowsDeviceLinkAssociation` | `Changed=True`, `AssociatedLocally`, firmware `4/4`, JWT `Valid`, `IdentityMatch=True`, native error `0x00000000` |
| Repeat completion | `Changed=False`, `AlreadyComplete=True`; no new native configure operation, retry, cleanup or reboot |
| Cloud verification after completion | `associated`, same Association ID, firmware `4/4`, no association error |
| Removal by Association ID | `Removed=True`; independent lookup confirmed `NotAssociated` while local firmware remained `4/4` |
| Local reset with `-Confirm:$false -PassThru` | All four variables removed and verified absent; each `Present=False`, size `0`, Win32 `203` |
| Repeat reset, with and without `-PassThru` | No firmware state present; no removal action; remained `0/4` |
| Local status after reset | New Link ID and base `2/4`; JWT variables absent; `CloudChecked=False`; no errors |

JWT `Valid` here describes the module's structure/time/identity checks.
`SignatureValidation=NotPerformed` was reported; cryptographic signature verification
is not claimed. Native configuration took 21.6 seconds in this run; the total command
time included the human confirmation wait and is not a configuration benchmark.

The firmware timestamp changed during completion while the Link ID stayed the same.
`FirmwareCreationTimeUtc` must therefore not be presented as an immutable original
identity creation time. It remained distinct from the per-payload timestamp.

During Interactive testing, passkey selection also failed independently in Edge and
Chrome. Restarting Windows restored the dialog and authentication succeeded. The root
cause was not established; no WindowsDeviceLink code fix is inferred from that recovery.

### Scope and remaining evidence

This run does not certify every architecture, tenant configuration or failure mode.
Subsequent configuration loading, fixed-tenant and switching evidence is recorded
below. Earlier app-authentication evidence is retained without a blanket rerun. Earlier Backend,
ARM64, WinPE and OOBE evidence below remains applicable to its recorded builds; those
complete lifecycles are not being repeated solely to remove the preview label.

The first live inline single-tenant Configuration check subsequently failed on the
published 0.12.1-preview1 package: the signed-out GUI showed "Determined by sign-in"
instead of the configured fixed tenant name. The GUI's conditional assignment allowed
a one-entry catalog to become a scalar, so its PowerShell 5.1 Count check did not select
the fixed tenant. The correction captures the entire conditional output as an array;
the regression test now executes that production loading statement instead of injecting
an already normalized array. The corrected source build at
`3aa88cc4d570cb48e50e366a3c240d9cd41e634d` subsequently passed the live inline fixed-tenant
check: the configured name persisted before sign-in, after successful Interactive
sign-in/cloud lookup, and after sign-out. Sign-out cleared the account and disabled
cloud actions; the last cloud result and its check time remained displayed.
The published preview does not contain this correction.

The same source build loaded a two-tenant inline configuration and successfully
signed in and queried the first tenant with the selector locked. The next step found
a second defect: sign-out cleared authentication but left the selector disabled.
The sign-out handler now restores the complete idle UI state. A regression check
executes the production sign-out, authentication-clear and idle-state functions for
Interactive and DeviceCode, with visible and hidden selectors. The second-tenant
Interactive sign-in and lookup passed after a Refresh local workaround on the earlier
source build. Source commit `f5f99633ca25c8fe58db5f04f6d6de865f6c5890` then passed the
live sign-in/lookup/sign-out check: the dropdown was enabled immediately after sign-out.

The operator requested a clearer signed-out cloud display after observing the retained
last result. Sign-out now discards the cached cloud association and resets all four cloud
card values and tooltips to Not checked, while preserving the selected target and local
state. Regression coverage checks this for Interactive and DeviceCode. The live
Interactive check on source commit `b1861088304bdbab3d47450f36508065676188af` passed:
all four cloud-card values returned to Not checked, the account was cleared and the
selector was enabled. Historical activity-log entries remain.

The subsequent operator-requested refinement also resets a multi-tenant selector to
Select target tenant... and its tenant scope to Not selected on sign-out. A fixed
single tenant is preserved. The regression test checks that the effective selected
tenant is empty after multi-tenant sign-out for both Interactive and DeviceCode.

### Subsequent source-build configuration and sign-out validation

On 2026-10-02, the operator tested immutable source commit
`de82a23e87b1256c7a3ccead6cc36e1c7779bc78` (merged through PR #68; still displaying
`0.12.1-preview1`, but not the published Gallery artifact):

- Inline two-tenant configuration loaded, and Interactive sign-out cleared the account
  and cloud card, unlocked the selector and returned it to Select target tenant....
- Interactive switching and cloud lookup succeeded in both directions across the
  session. Some attempts failed as described below; an uninterrupted round trip is
  not claimed. After restarting Windows, the operator confirmed first-tenant sign-in,
  sign-out and second-tenant sign-in succeeded on this unchanged source build.
- Local JSON file loading displayed both configured tenants (load/display check only).
- HTTPS loading of the commit-pinned `configuration-multiple.example.json` displayed
  Tenant Alpha and Tenant Beta. These fictional tenants were not used for sign-in.
- DeviceCode sign-in followed by sign-out passed: signed-out status, cleared account,
  cloud card Not checked and selector reset to Select target tenant.... No device
  registration, removal or firmware reset was repeated for this UI check.

During the Interactive switching investigation, Graph authentication reported
`InteractiveBrowserCredential authentication failed: User canceled authentication`
despite the operator not intentionally cancelling. A fresh PowerShell session still
reproduced the GUI failure. A separate raw Graph 2.41.0 sign-in test succeeded for both
tenants; a Microsoft sign-in page also showed a passkey sign-in failure. The GUI switch
succeeded after a Windows restart. This supports an authentication-environment issue
as a hypothesis, but does not establish the root cause or prove the GUI uninvolved.
No authentication code change or automatic retry was introduced to mask the failure.

The operator reconfirmed that own app registrations, including certificate-based
authentication, were tested in an earlier phase. That operator-reported historical
evidence is retained; those authentication tests are not repeated solely for stable.
The exact earlier artifact and shared/per-tenant Direct JSON combinations were not
re-established in this follow-up. Current Direct GUI clientId precedence and routing
have automated coverage, not a newly claimed live custom-app pass. Certificate-based
app-only authentication is distinct from current delegated Direct GUI authentication.
A further live custom-app routing check is deferred unless a relevant change or
concrete regression warrants it; it is not a stable release gate.

Do not treat the [historical 0.10 test plan](docs/TEST-MATRIX-0.10.0.md) as the current
authentication matrix. Current Direct authentication is Interactive or DeviceCode;
certificate/client-secret authentication belongs to the backend's Graph connection.

The primary Windows Autopilot Device Preparation Device Association workflow has been validated on physical AMD64 hardware across Windows 11 and AMD64 Windows PE. The full-Windows workflow has also been validated end to end on physical ARM64 hardware through the registered system runtime. ARM64 WinPE and x64-emulated PowerShell on ARM64 remain unsupported.

## Confirmed direct functionality

| Area | Windows 11 | Windows PE |
|---|---:|---:|
| Runtime support detection | Pass | Pass |
| DeviceLink generation | Pass | Pass |
| Graph pre-association | Pass | Pass |
| Duplicate / HTTP 409 handling | Pass | Pass |
| Native `.devicelink.csv` generation | Pass | Pass |
| CSV accepted by Intune | Pass | Pass |
| Export to directory / root | Pass | Pass |
| Device-code authentication | Pass | Pass |
| Device Association lookup: no match | Pass | Pass via status lookup |
| Device Association lookup by serial number | Pass | Pass via status lookup |
| Device Association lookup by association ID | Pass | Not repeated |
| Device Association removal by serial number | Pass | Pass |
| Device Association removal by association ID | Pass | Not repeated |
| `Get-WindowsDeviceLinkStatus` local status | Pass | Pass |
| `Get-WindowsDeviceLinkStatus -Online` with preassociation | Pass | Not repeated |
| `Get-WindowsDeviceLinkStatus -Online` with association | Pass | Pass |
| `Test-WindowsDeviceLinkHealth` local | Pass | Pass |
| `Test-WindowsDeviceLinkHealth` online associated | Pass | Pass |
| `Initialize-WindowsDeviceLink` LocalOnly -> Preassociated | Pass | Not repeated |
| `Initialize-WindowsDeviceLink` preassociated idempotency | Pass | Not repeated |
| `Initialize-WindowsDeviceLink` associated idempotency | Pass | Pass |
| `Get-WindowsDeviceLinkFirmwareState` | Pass | Pass |
| Firmware timestamp, whole seconds | Pass | Pass-compatible parser |
| Firmware timestamp, fractional seconds | Pass | Pass |
| Firmware reset operation | Pass | Pass |
| Firmware reset `-WhatIf` | Pass | Pass |
| Post-reset firmware verification | Pass | Pass |
| Post-reset reboot remains 0/4 until DeviceLink identity retrieval | Pass | Not repeated |
| New base identity materialized by DeviceLink retrieval after reset | Pass | Pass (identity created after WinPE reset) |
| Published PSGallery package import (0.4.4-preview1) | Pass | Pass |
| Published package support probe (0.4.4-preview1) | Pass | Pass with user-supplied DLL |
| Published package firmware read (0.4.4-preview1) | Pass | Pass |
| Published package local status (0.4.4-preview1) | Pass | Pass |
| Published package online associated health (0.4.4-preview1) | Pass | Pass |

## 0.4.4 command-boundary, Device Association, health and initialization validation

`0.4.4-preview1` separates the local DeviceLink identity from tenant-side Device Association state and adds combined status, health classification and safe idempotent initialization.

The intended command boundaries are:

```text
Get-WindowsDeviceLink
    local DeviceLink identity only

Get-WindowsDeviceLinkFirmwareState
    local UEFI state only

Get-WindowsDeviceLinkAssociation
    tenant-side Intune/Graph Device Association only

Get-WindowsDeviceLinkStatus
    combined diagnostic view; local by default, cloud only with -Online

Test-WindowsDeviceLinkHealth
    classifies a status object without changing state

Initialize-WindowsDeviceLink
    safe orchestration; creates a missing preassociation only for validated LocalOnly state
```

### Physical Windows 11 validation

Validated on physical AMD64 Windows 11 devices, including OOBE:

- `Get-WindowsDeviceLink` returned the local identity without authentication or Graph activity;
- the former `Get-WindowsDeviceLink -Online` parameter is no longer present;
- Device Association lookup returned no result before registration;
- `Register-WindowsDeviceLink -Method DeviceCode` created a `preassociated` record;
- `Get-WindowsDeviceLinkAssociation` returned that record by serial number and association ID;
- `Get-WindowsDeviceLinkStatus` returned runtime, local identity and firmware state without cloud authentication;
- a base/preassociated local identity showed two of four known firmware variables present;
- `Get-WindowsDeviceLinkStatus -Online` correlated the same local identity with the tenant-side `preassociated` record;
- `Test-WindowsDeviceLinkHealth` classified local 2/4 state without cloud lookup as `LocalBaseIdentity`;
- the same local 2/4 state with a confirmed absent tenant association was classified as `LocalOnly`;
- `Initialize-WindowsDeviceLink -WhatIf` on `LocalOnly` reported `Action=Register` and `Changed=False`;
- a real initialization transitioned `LocalOnly` to `Preassociated` and verified the result through the read path;
- an already preassociated device returned `Action=None`, `Changed=False`, `BeforeState=Preassociated`, `AfterState=Preassociated`;
- an associated device with 4/4 firmware returned `Action=None`, `Changed=False`, `BeforeState=Associated`, `AfterState=Associated`;
- DeviceCode initialization reuses one access token for lookup, registration where required, and verification.

### Physical AMD64 WinPE validation for 0.4.4

The same physical associated Dell device was validated first in Windows 11 OOBE and then in AMD64 WinPE.

Validated in WinPE:

- `Test-WindowsDeviceLinkSupport` reported `Environment=WindowsPE`, `Architecture=AMD64`, `Supported=True`, `DllSource=Bundled` and `ActivationMode=DirectDll` when a compatible runtime DLL was supplied;
- `Get-WindowsDeviceLinkFirmwareState` returned all four known firmware variables as present;
- `Get-WindowsDeviceLinkStatus` worked fully locally in WinPE with `DeviceLinkPresent=True`, `FirmwareStateComplete=True`, `FirmwareVariablesPresent=4/4`, `CloudChecked=False`;
- local health was classified as `LocalCompleteFirmwareState` with informational severity;
- `Get-WindowsDeviceLinkStatus -Online -Method DeviceCode` successfully correlated the WinPE identity with the existing tenant-side Device Association;
- online health returned `State=Associated`, `CloudChecked=True`, `AssociationPresent=True`, `AssociationState=associated`, `FirmwareVariablesPresent=4/4` and no association error;
- `Initialize-WindowsDeviceLink -Method DeviceCode` on the already associated device returned `Action=None`, `Changed=False`, `BeforeState=Associated`, `AfterState=Associated` and performed no registration or firmware change;
- one DeviceCode sign-in was used for the initializer operation.

No tenant IDs, serial numbers, Link IDs, SMBIOS UUIDs, association IDs or device-code values from the live validation are retained in this document.

### Physical ARM64 Windows 11 validation recorded for 0.12

Validated with native ARM64 Windows PowerShell 5.1 on a physical ARM64 Windows 11 device using the architecture-matching registered system runtime:

- support detection reported `Environment=Windows`, `Architecture=ARM64`, `Supported=True`, `DllSource=System` and `ActivationMode=RegisteredWinRT`;
- local DeviceLink identity retrieval and native `.devicelink.csv` export succeeded;
- backend tenant lookup and pre-association succeeded from a base identity with two of four firmware variables present;
- native association completion succeeded and produced a valid, identity-matching association JWT with all four firmware variables present;
- local and cloud refresh both returned the expected associated state;
- cloud-only removal preserved the complete local firmware state;
- local-only reset returned the device to a two-variable base identity;
- combined cloud and local offboarding returned the device to base identity with no tenant-side association;
- reassignment, pre-association and association against another configured tenant completed successfully;
- the operator GUI displayed `Windows 11 (ARM64)` and maintained correct action states throughout the lifecycle.

The same ARM64 device was also checked from x64-emulated PowerShell. That path is deliberately rejected because the architecture-mismatched native runtime fails with `0x800700C1`. ARM64 support therefore requires a native ARM64 Windows PowerShell process. ARM64 WinPE and direct ARM64 DLL activation were not enabled or claimed by this work.

No tenant names or IDs, profile names, serial numbers, Link IDs, SMBIOS UUIDs or association IDs from the live ARM64 validation are retained in this document.

## Health regression validation

The hardware-independent health regression suite was run successfully under Windows PowerShell 5.1.

Validated classifications include:

- Unsupported;
- IdentityUnavailable;
- FirmwareUnavailable;
- CloudUnknown;
- FirmwareStateUnknown;
- NoFirmwareState;
- IncompleteFirmwareState;
- LocalBaseIdentity;
- LocalCompleteFirmwareState;
- LocalOnly;
- CloudAssociationMissingWithCompleteFirmware;
- Preassociated;
- PreassociatedUnexpectedFirmwareState;
- Associated;
- AssociatedIncompleteFirmwareState;
- UnclassifiedAssociationState.

The suite also validates invariants preventing incomplete associated firmware from being reported as healthy `Associated`, and preventing cloud lookup failures from being interpreted as `LocalOnly`/`NotAssociated`.

## Online method validation

The `0.4.4-preview1` API places authentication on explicit tenant-side operations rather than on `Get-WindowsDeviceLink`.

The parameter regression suite passed, including validation that:

- `Get-WindowsDeviceLink` no longer accepts `-Online`;
- webhook registration requires `WebhookUri` and rejects cloud-only authentication inputs;
- delegated `Interactive` and `DeviceCode` authentication can omit `TenantId`; `DeviceCode` defaults to the `organizations` authority;
- Device Association lookup requires exactly one selector;

The current Direct surface supports Interactive and DeviceCode only. Backend and low-level Webhook use API authentication. App-only and public AccessToken routes are rejected; internal delegated token reuse remains covered by regression tests.

Backend configuration regression tests cover a shared multitenant application profile,
separate certificate/client-secret profiles, tenant-specific token acquisition, and a
Move whose source and target use different profiles. Live validation is required only
for the shared multitenant application route; isolated per-tenant applications are
validated with mocked identity and Graph transports.



## Operator GUI validation

`Show-WindowsDeviceLink` has been exercised on physical AMD64 and ARM64 Windows 11,
and on AMD64 Windows PE hardware. Backend mode was validated through a real Function
deployment with an authenticated multitenant catalog.

Validated GUI behavior includes:

- startup on full Windows without materializing a new DeviceLink identity implicitly;
- module version and Preview status in the window title;
- Windows 11 environment display;
- local firmware / tenant-correlation display;
- tenant selector with friendly names (the new Configuration schema still needs live UI validation);
- default `Interactive` authentication and alternate `-Method` contract;
- online cloud-state refresh;
- CSV export;
- pre-association;
- association with live Information-stream progress;
- cloud-only offboarding;
- local-only firmware reset;
- fail-safe full offboarding that verifies cloud state before local reset;
- consistent disabled action state while operations are running;
- activity logging and clear action;
- compact full-Windows layout with conditional outer scrolling;
- native Windows confirmation dialogs.

The hardware-independent `Gui-Contract-Validation.ps1` suite validates export, authentication defaults, tenant-selector contract, WinPE guardrails and delegation to existing public cmdlets.

### Windows PE GUI validation

Validated on physical AMD64 Windows PE:

- GUI startup with WinForms available;
- explicit administrator-supplied `Windows.Management.Service.dll` activation;
- local refresh and backend Device Association lookup;
- DeviceLink CSV export;
- backend pre-association and verified tenant reassignment;
- **Associate** visible but disabled because device-side completion belongs to
  full Windows/OOBE;
- cloud-only offboarding;
- local firmware reset;
- combined cloud and local offboarding;
- automatic action-state refresh after each operation.

The default Direct-mode authentication in Windows PE is `DeviceCode`, not
`Interactive`. Broader Direct-mode GUI authentication testing is tracked separately
from the focused `0.12.0-preview1` release gate.

The GUI must remain usable when the DeviceLink runtime is unavailable: runtime-dependent actions are disabled and the blocking reason is surfaced through Activity/tooltips rather than terminating the dashboard.

## Local tenant discovery validation

Validated on a physical Microsoft Surface Laptop 3 running AMD64 Windows 11.

The public `Get-WindowsDeviceLinkLocalAssociation` command was exercised across the lifecycle and confirmed to remain fully local (`CloudChecked=False`).

Observed sequence:

- associated `4/4`: current-LinkId registry `TenantIdHint` and JWT `tenantId` both present and equal -> `CorrelatedLocalSources`;
- cloud Device Association deleted while UEFI remained `4/4`: local tenant ID remained readable;
- UEFI reset to `0/4`: old registry hints remained but no tenant was selected because no current LinkId existed;
- new base identity materialized to `2/4`: no matching current-LinkId TenantIdHint existed and local tenant remained unavailable;
- Graph preassociation alone: still no current-LinkId TenantIdHint;
- read-only native discovery: wrote the current-LinkId `TenantIdHint` and `DiscoveryUrl` while firmware remained `2/4`;
- association completion: JWT variables returned and the JWT `tenantId` again matched the registry hint.

The hardware-independent `Local-Association-Validation.ps1` regression suite passed for matching sources, registry-only, JWT-only, conflict and unavailable states. The conflict path returns no selected TenantId.

Independent online JWT validation research confirmed structural/time/device correlation but did not locate a published signing key for the observed `DeviceTag_<guid>` issuer; signature verification therefore remains `NotPerformed`.
## Firmware lifecycle validation

Validated UEFI namespace:

```text
{B3DE75DA-819C-4FD5-9F01-C3D49E8CBBD7}
```

Validated variables:

```text
DeviceLinkId
DeviceLinkJwtCompressed
DeviceLinkJwtLastWrite
DeviceLinkCreationTimeUtc
```

The raw `DeviceLinkJwtCompressed` value is treated as sensitive and must not be logged or published.

### Observed states

- Clean baseline: all four variables absent.
- After DeviceLink generation: `DeviceLinkId` and `DeviceLinkCreationTimeUtc` present; JWT variables absent.
- After preassociation: same local base identity state; JWT variables still absent.
- Associated Windows device: all four variables present.
- Server-side association removal: local firmware state remains until explicitly reset.

### DeviceLinkCreationTimeUtc format

Live validation established that `DeviceLinkCreationTimeUtc` is a UTF-8 ISO-8601 UTC timestamp. At least two representations have been observed on physical hardware:

```text
2026-09-06T12:22:51Z
2026-09-15T07:48:22.972Z
```

The first observed representation was 20 bytes and used whole seconds. A second associated Dell device exposed a 24-byte value with milliseconds. The 0.4.4 parser accepts both whole and fractional seconds.

The fractional-seconds parser was explicitly revalidated in a fresh AMD64 WinPE PowerShell 5.1 session. `DecodedValue` returned the exact UTC text and `ParsedUtc` returned the parsed UTC `DateTime`. `DecodedValue` remained empty for `DeviceLinkId`, `DeviceLinkJwtCompressed` and `DeviceLinkJwtLastWrite`.

`PayloadCreationTimeUtc` is separate: it belongs to the newly generated DeviceLink payload and changes between payload generations. The firmware creation timestamp remains stable across those generations. The module therefore exposes the two concepts separately.

### AMD64 WinPE lifecycle

Validated in WinPE:

1. read clean firmware state;
2. generate DeviceLink;
3. verify base identity variables appeared;
4. create Graph preassociation;
5. remove the server-side association;
6. reset local DeviceLink firmware variables;
7. verify all four variables absent afterward.

### Full Windows reset and identity materialization

A controlled end-to-end offboarding test established the post-reset behavior more precisely:

1. the device started associated with all four known UEFI variables present;
2. all four UEFI variables were removed and immediately verified absent with Win32 error `203`;
3. the tenant-side Device Association record was removed successfully by local serial-number autodetection;
4. a follow-up tenant lookup confirmed that no Device Association record remained;
5. after reboot, the firmware state still showed **0/4**;
6. `Get-WindowsDeviceLink` was then invoked;
7. immediately afterward, `DeviceLinkId` and `DeviceLinkCreationTimeUtc` were present again while both JWT variables remained absent, producing the expected base **2/4** state.

Conclusion: reset removes the old local DeviceLink identity. A reboot alone does not necessarily recreate the base identity. A later DeviceLink identity retrieval can materialize a **new** base identity. Reappearance of the base variables does not mean the old tenant association was restored.

## Device Association removal validation

The Device Association removal operation was derived from the Intune admin center request and independently verified as:

```text
DELETE /deviceManagement/tenantAssociatedDevices/{associationId}
```

Validated standalone deletion, removal by serial number, removal by association ID in Windows 11, and removal by serial number from AMD64 WinPE. The cmdlet targets Device Association records (`tenantAssociatedDevices`) and does **not** use the classic Autopilot V1 deletion API.

## Published 0.4.4-preview1 Gallery smoke test

The actual `0.4.4-preview1` package published to PSGallery was tested after publication rather than relying only on the repository checkout.

### Windows 11 OOBE

Validated on physical AMD64 Windows 11 OOBE hardware, including local/online status and health, Device Association lifecycle states, and initializer behavior. `Preassociated` and `Associated` devices were both confirmed idempotent with `Action=None` and `Changed=False`.

### AMD64 Windows PE

The installed Gallery package was then exercised on the same physical associated device in AMD64 WinPE.

Validated findings:

- the installed module reported version `0.4.4` from the Windows PowerShell module path rather than the repository checkout;
- without `Windows.Management.Service.dll`, `Test-WindowsDeviceLinkSupport` correctly reported WinPE/AMD64/direct-DLL mode as unsupported because the runtime DLL was absent;
- after a compatible user-supplied Microsoft DLL was placed in the installed module's `Runtime` directory, support changed to `Supported=True` with `ActivationMode=DirectDll`;
- `Get-WindowsDeviceLinkFirmwareState` returned all four known variables;
- the 24-byte fractional `DeviceLinkCreationTimeUtc` value decoded and parsed successfully while the other firmware values remained undisclosed;
- `Get-WindowsDeviceLinkStatus` returned `Environment=WindowsPE`, `DeviceLinkPresent=True`, `FirmwareStateComplete=True`, `FirmwareVariablesPresent=4/4` and the parsed firmware creation time;
- `Get-WindowsDeviceLinkStatus -Online -Method DeviceCode | Test-WindowsDeviceLinkHealth` returned `State=Associated`, `CloudChecked=True`, `AssociationPresent=True`, `AssociationState=associated` and no association error.

The current WinPE `-SkipPublisherCheck` requirement remains documented as a workaround for the unsigned preview and will be retested after trusted code signing is introduced.

See [`docs/INSTALLATION.md`](docs/INSTALLATION.md) for the supported installation routes and troubleshooting guidance.

## Webhook validation

The webhook/pre-association contract has been validated end-to-end on Windows 11. The
Azure Function backend tenant catalog, complete lookup, New/no-op and guarded Move paths
have also been validated live across two configured test tenants. Bidirectional tenant
moves were completed successfully from AMD64 Windows PE after the device-side workflow
renewed the local DeviceLink identity, and the final target state was verified through
the backend lookup path.

See [`docs/WEBHOOK-SCHEMA-v1.md`](docs/WEBHOOK-SCHEMA-v1.md).

## Notes

- Full Windows uses the registered Windows Runtime and system `Windows.Management.Service.dll`.
- WinPE uses direct DLL activation.
- The public PowerShell Gallery package does **not** redistribute `Windows.Management.Service.dll`; WinPE Gallery users must provide a compatible copy themselves.
- Native CSV generation is used; WindowsDeviceLink does not reconstruct the CSV format.
- Firmware access requires `SeSystemEnvironmentPrivilege`; the firmware cmdlets enable it in the current process.
- PowerShellGet `Save-Module` does not exercise the same install/publisher-check path as `Install-Module`; both routes were tested separately in WinPE.

## Published preview

The earlier repository validation described above covers the `0.12.0-preview1` candidate,
including the operator GUI on physical AMD64 and ARM64 Windows 11 and AMD64 Windows PE hardware.
The GUI lifecycle tests cover pre-association, association, idempotency,
cloud/local/full offboarding, stale local/cloud combinations, tenant-source correlation,
DeviceCode token reuse, WinPE CSV export, authenticated backend tenant selection, and
bidirectional guarded tenant moves. The supplied Function App package is the supported
preview backend delivery route; the Bicep/ARM Deploy to Azure path remains experimental.

## Remaining validation / future work

The ordered [current checklist](docs/VALIDATION-CHECKLIST.md) tracks live tests, UI review,
screenshots and package verification. The items below retain the broader research and
compatibility scope; they are not all required for the next preview.

- Trusted code signing; the initial SignPath Foundation application was reviewed but not approved because the project does not yet have enough external adoption/visibility signals. Revisit SignPath or another trusted signing path later.
- Retest normal WinPE `Install-Module` without `-SkipPublisherCheck` after signing.
- Retest and optimize the beta Device Association serial-number server-side lookup; the current client-side fallback is functionally correct.
- Retain earlier app-authentication evidence and automated custom client-app routing
  coverage; repeat live custom-app routing only for a relevant change or regression.
  Fixed tenant labels, JSON loading, tenant switching and sign-out have live evidence.
  The 2026-10-02 record above
  covers the published 0.12.1-preview1 Windows 11 AMD64 base authentication/lifecycle;
  do not restart the entire historical Direct or Backend matrix.
- Harden and validate the experimental Bicep/ARM Deploy to Azure route tracked in issue #43.
- Additional Windows 11 / WinPE builds and OEMs/models.
- Non-Global Microsoft clouds.

## Configuration validation

Offline checks cover JSON file/HTTPS/inline loading, strict schema validation, duplicate
names and IDs, clientId precedence, conflicting parameters, single-tenant fixed labels,
multitenant selection and client routing for Interactive/DeviceCode.

No further live configuration rerun is required for the agreed stable scope.
Loading, fixed-tenant naming, tenant switching and sign-out results are recorded above.
Earlier app-authentication evidence is retained; exact custom-client JSON combinations
are not relabeled as a new live pass. WinPE-specific Direct Configuration coverage is deferred as described in the
current checklist, not marked as passed. Backend catalog behavior must remain unchanged.
