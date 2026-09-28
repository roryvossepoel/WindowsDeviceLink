# Current validation and polish checklist

Reviewed: 2026-09-28. Current published preview: `0.12.0-preview1`.

Work through the numbered items in order. Record the exact module version and source
commit used for each run; a later UI fix may need a new candidate and targeted retests.
This is the active checklist. [TESTING.md](../TESTING.md) retains previous evidence;
the 0.10 matrix and 0.4.x lifecycle plan are historical documents.

No new hardware tests were performed during this documentation review. Pending means
that a complete current-run record is still needed, not that the feature has never worked.
Previously recorded Backend lifecycle results remain valid evidence for the tested builds.

## 1. Direct on Windows 11

**Status: Pending current-run evidence.** Start on physical AMD64 Windows 11; repeat
the authentication and tenant-selection paths on ARM64 using native ARM64 PowerShell.

- [ ] Interactive: sign in, cancel/retry, refresh cloud, sign out and sign in again.
- [ ] DeviceCode: sign in once, reuse the session, refresh, handle expiry and sign out.
- [ ] Test CLI and GUI with the sign-in tenant and with an explicit target tenant.
- [ ] Check New pre-association, target-present no-op, completion on supported full
  Windows, and cloud removal. Verify returned objects as well as the displayed state.
- [ ] Check Direct configuration from a local JSON file, HTTPS and inline JSON.
- [ ] Check a fixed tenant name and a multiple-tenant selector before/after sign-in.
- [ ] Sign out, switch tenant, sign in and verify that cloud actions use the new tenant.
- [ ] Verify shared and tenant-specific client IDs and a denied-permission case.

Done when both supported authentication methods and the tenant-selection paths have
recorded results. Direct supports multiple tenants but checks one selected tenant per
operation. Certificate/client-secret authentication belongs to Backend, not Direct.

## 2. Direct on AMD64 Windows PE

**Status: Pending current-run evidence.** Use DeviceCode and a compatible
administrator-supplied runtime DLL; record the WinPE build and DLL version.

- [ ] Verify support detection and local status with the DLL present and missing.
- [ ] Complete DeviceCode sign-in, cloud refresh, pre-association, no-op and removal
  through CLI and GUI.
- [ ] Repeat fixed-tenant and multiple-tenant configuration, including tenant switching.
- [ ] Verify CSV export and the explanation for the unavailable Associate action.

Done when the pre-association workflow works independently of the Function App.
Native completion is performed later in Windows 11/OOBE. ARM64 WinPE is unsupported.

## 3. Operator UI review

**Status: Pending visual review.** Record findings from the authentication tests above
before changing the layout.

- [ ] Check 1366x768 and 100%, 125%, 150% and 200% display scaling; content must remain
  reachable, using scrolling where needed.
- [ ] Check long tenant/account names, long errors, keyboard focus and tab order.
- [ ] Make selected tenant, signed-in account, local state and cloud state unambiguous.
- [ ] Check initial, loading, success, no-op, unknown and blocked states.
- [ ] Check progress and actionable failure text; verify Copy and Clear activity actions.
- [ ] Confirm removal/reset dialogs describe the affected tenant and local/cloud scope.
- [ ] Recheck action availability after sign-out, a failed operation and a tenant change.

Done when findings are fixed or explicitly documented and affected paths are retested.
Existing GUI behavior is described in the [GUI guide](GUI.md); these are review criteria,
not a list of confirmed defects.

## 4. Failure handling and targeted Backend regression

**Status: Core Backend lifecycles already recorded; targeted current-candidate checks pending.**

- [ ] Exercise denied permissions, cancelled/expired sign-in and network interruption.
- [ ] Confirm failed lookup is Unknown, not NotAssociated; an incomplete or ambiguous
  Backend lookup must not trigger a mutation.
- [ ] Verify timeout recovery starts with a fresh lookup instead of blindly repeating
  a potentially completed write.
- [ ] Check New, no-op, Move in both directions, repair when applicable, and offboarding
  after changes affecting those paths. Include source and target verification.
- [ ] Check unattended Backend CLI catalog, status, assignment and removal without
  prompts when the supported confirmation inputs are supplied.
- [ ] Record the Backend authentication profile used. Validate the shared multitenant
  app route live; isolated per-tenant profiles have mocked regression coverage.
  If an additional certificate/client-secret route is tested, record it separately.
- [ ] Inspect output and errors for exposed credentials, raw JWTs or DeviceLink payloads.

Done when failures leave a clear, recoverable state and changed lifecycle paths retain
their safety behavior. Do not repeat every historical test for an unrelated text change.
Device Association cleanup does not itself end MDM enrollment; follow [offboarding](OFFBOARDING.md).

## 5. Deployment chain through OOBE

**Status: Pending a consolidated run record for this checklist.** Earlier Windows/OOBE
and pre-association evidence is retained in TESTING.md.

- [ ] Pre-associate in AMD64 WinPE, install Windows 11 and complete OOBE with network access.
- [ ] Verify the intended tenant and Device Association state in local and cloud views.
- [ ] Record enrollment and provisioning results separately: Associated alone does not
  mean Intune enrollment or application delivery is complete.
- [ ] Repeat a transition with an existing Autopilot v1 registration, leaving that object
  in place and recording the resulting device preparation flow.

Done when the complete handoff is evidenced. See the [migration FAQ](FAQ.md#do-i-need-to-delete-the-autopilot-v1-object-before-transitioning-to-device-preparation).

## 6. Package and release verification

**Status: Final candidate/artifact evidence pending.**

- [ ] Run CI against the exact source commit, including documentation checks.
- [ ] Install the candidate in a clean session and verify the loaded version and module
  path on Windows 11 AMD64, Windows 11 ARM64 and AMD64 WinPE.
- [ ] Check support, local status, GUI startup and one appropriate cloud operation.
- [ ] Verify the staged package contains no Microsoft runtime DLL or environment credentials.
- [ ] After publication, repeat the short smoke test using the actual Gallery artifact
  and record that package separately from the source checkout/candidate.
- [ ] Record the WinPE installation route and whether the documented unsigned-package
  workaround was required. Retest without it only when the signing situation changes.

Done when the artifact users install matches the tested release and documentation.
Documentation-only updates do not require republishing an unchanged module.

## 7. Final screenshots and documentation pass

**Status: Two sanitized examples published; remaining state-specific images pending.**

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

Leave untested combinations unchecked. Do not retain real tenant/user/device identifiers,
API keys, device codes, raw JWTs or DeviceLink payloads in public evidence.

## Separate follow-up projects

These remain outside the current polish/test checklist:

- [GitHub Pages documentation site (#48)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/48).
- [Deploy to Azure validation (#43)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/43).
- [Optional device preparation policy selection (#47)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/47).
- [Trusted code signing (#3)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/3), currently dependent on obtaining a trusted signing path.
- [Official WinPE runtime acquisition (#2)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/2) and [serial lookup performance (#1)](https://github.com/roryvossepoel/WindowsDeviceLink/issues/1).
