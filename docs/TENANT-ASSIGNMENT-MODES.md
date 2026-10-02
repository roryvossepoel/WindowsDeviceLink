# Tenant assignment modes

WindowsDeviceLink supports several operator flows through two execution routes:

- **Direct** — the device talks directly to Microsoft Graph.
- **Backend** — the device delegates catalog lookup and tenant assignment to the
  WindowsDeviceLink Function App.

**Both Direct and Backend support multiple tenants.** Direct operates in one selected
tenant at a time: use the sign-in context or an explicit `TenantId` in the CLI, or a
configured tenant selector in the GUI. Backend mode is the recommended route for
ongoing multitenant management because it checks all configured tenants and supports
verified tenant moves. Direct remains useful for interactive work across known
tenants, fixed-purpose media, and environments without the Function App.

## Choose a mode

| Mode | Who determines the tenant? | Authentication | Best suited for |
|---|---|---|---|
| Account-based Direct | The signed-in account context | Delegated user token | Ad-hoc work in one tenant at a time |
| Fixed-tenant Direct | A supplied `TenantId` | Delegated operator sign-in | Dedicated scripts or media for one enforced tenant |
| Delegated catalog Direct | Operator selection from a catalog | User plus delegated app permissions | A small tenant list without a backend |
| Backend | Operator selection from the Function catalog | Function API access; Graph credentials stay in Azure | Structural multitenant lookup, registration, and verified Move |

If a device may already exist in another managed tenant, choose **Backend**. Direct
mode can inspect only its current target tenant and therefore cannot prove that the
device is absent elsewhere.

## GUI and CLI are different operator surfaces

The modes describe authentication and tenant scope; they do not imply that every
workflow is unattended.

| Mode | GUI flow | CLI automation |
|---|---|---|
| Account-based Direct | Operator selects **Sign in** and completes user authentication | Not fully unattended; Interactive or DeviceCode requires a user |
| Fixed-tenant Direct with delegated auth | Tenant is hidden and enforced; operator still signs in | Target is deterministic, but user authentication remains interactive |
| Delegated catalog Direct | Operator selects a tenant, then signs in against it | A script can resolve the catalog entry, but delegated authentication still requires a user or existing SSO context |
| Backend | Operator selects the Function-provided target and chooses **Pre-associate** or **Associate** | Can be unattended by calling `Set-WindowsDeviceLinkTenant` with an explicit target |

The GUI remains an operator interface: even with non-interactive authentication, tenant
selection and registration are intentional operator actions. For zero-touch
execution, use the CLI and pass or resolve the target tenant in the script.

Examples of CLI-oriented choices:

```powershell
# Account-based or delegated: user interaction is expected.
Set-WindowsDeviceLinkTenant -Method DeviceCode

# Backend: preferred unattended multitenant route.
Set-WindowsDeviceLinkTenant `
    -BackendUri 'https://<app>.azurewebsites.net/api/devicelink' `
    -BackendApiKey $apiKey `
    -TargetTenantId '<tenant-id>'
```

## Account-based Direct mode

Start the GUI without a tenant ID or catalog:

```powershell
Show-WindowsDeviceLink
```

The GUI shows no tenant selector. The tenant that issues the delegated sign-in token
becomes the target tenant. **Sign out**, followed by **Sign in**, starts a new sign-in, allowing another
tenant to be used in a later session.

This mode still uses an app registration. When no custom `ClientId` is supplied, the
underlying Microsoft Graph authentication client is used. Effective access is limited
by both the delegated permissions granted to that client and the rights of the signed-in
user.

Use this mode when flexibility is intentional and the operator can reliably select the
correct account and tenant during sign-in.

## Fixed-tenant Direct mode

Supply one tenant ID to enforce the authority used for authentication and Graph calls:

```powershell
Show-WindowsDeviceLink -TenantId '<tenant-id>'
```

The GUI shows no tenant selector. The operator cannot redirect the workflow to another
tenant. This is useful for customer-specific WinPE media, scripts, or support workflows.

For a fixed friendly name, supply a configuration with one tenant instead.
Configuration cannot be combined with explicit TenantId or ClientId parameters.
See [the configuration schema](CONFIGURATION.md).

## Delegated catalog Direct mode

Supply a configuration with multiple tenants and use `Interactive` or `DeviceCode` authentication:

```powershell
Show-WindowsDeviceLink `
    -Method DeviceCode `
    -Configuration 'E:\Config\devicelink.json'
```

The operator must select a tenant before signing in. The selected tenant becomes the
authentication authority. A shared configuration clientId can identify a multitenant app registration in
every tenant where its service principal exists and delegated consent has been granted.
The signed-in user must also have sufficient rights in the selected tenant.

Changing the selected tenant invalidates the current GUI session. Microsoft sign-in may
reuse an existing SSO session, but WindowsDeviceLink must still obtain a new delegated
access token issued by the newly selected tenant. A token issued by one tenant is never
used for Graph operations in another tenant.

## Backend mode — recommended for multitenant

Backend mode is activated with `BackendUri` and `BackendApiKey`:

```powershell
$apiKey = Read-Host 'WindowsDeviceLink API key' -AsSecureString

Show-WindowsDeviceLink `
    -BackendUri 'https://<app>.azurewebsites.net/api/devicelink' `
    -BackendApiKey $apiKey
```

`Read-Host` is optional; it only collects the key interactively in this example.
For a private script with the key supplied directly in code, see
[launching the Backend GUI without an API-key prompt](GUI.md#launch-the-backend-gui-without-an-api-key-prompt).
The GUI still requires an operator to select the target and run actions.

The Function App provides the authoritative tenant catalog and keeps Microsoft Graph
credentials in Azure. The device receives neither the Graph certificate nor a client
secret. The backend checks every configured tenant before deciding what to do.

Backend mode supports:

- complete lookup across configured tenants;
- friendly centrally managed tenant names;
- New and no-op decisions;
- verified tenant-to-tenant Move;
- local DeviceLink identity renewal when required;
- target-state verification and centralized diagnostic correlation.

The API key authenticates the device to the Function App; it is not a Microsoft Graph
token. A backend failure never silently falls back to Direct mode.

## Authentication and token boundaries

Direct operator authentication and backend application authentication have different identities:

| Authentication | Executing identity | Graph permissions | Interactive user |
|---|---|---|---|
| Delegated | App registration plus user | Delegated | Yes |
| Backend | Function App's configured app identity | Application | No Graph login on the device |

A multitenant app registration provides a reusable application identity, not a universal
access token. Microsoft Entra issues a separate token for each target tenant. The Client
ID and certificate or secret may be reused where consent exists; the token may not.

## Functional and security differences

| Capability | Direct | Backend |
|---|---:|---:|
| Work with multiple tenants | Yes, one selected tenant per operation | Yes, with lookup across configured tenants |
| Operate in one known target tenant | Yes | Yes |
| Local or HTTPS friendly-name catalog | Yes | Function catalog |
| Prove absence from every configured tenant | No | Yes |
| Discover the current source tenant | No | Yes |
| Verified cross-tenant Move | No | Yes |
| Keep Graph application credentials off the endpoint | Yes | Yes |
| Central tenant allow-list and audit correlation | No | Yes |
| Useful without Azure infrastructure | Yes | No |

## Decision contract

| Proven state | Decision | Renew local identity |
|---|---|---|
| Direct target absent, firmware 2/4 | New | No |
| Direct target present | None | No |
| Backend: absent everywhere, firmware 2/4 | New | Yes |
| Backend: absent everywhere, stale firmware 4/4 | New | Yes |
| Backend: present in target | None | No |
| Backend: present in another tenant | Move | Yes |
| Backend lookup incomplete or ambiguous | Block | No mutation |

Assignment results expose `OperationMode`, `Decision`, `ReasonCode`, `Changed`,
`RetrySafe`, and `RecommendedAction`. An uncertain mutation requires a fresh read; it
is never blindly retried.

## Practical recommendation

- Choose **Account-based Direct** for simple interactive work in one tenant at a time.
- Choose **Fixed-tenant Direct** when the target must be enforced by configuration.
- Choose **Delegated catalog Direct** only when operators need a controlled list but no
  Function App is available.
- Choose **Backend** whenever tenant-to-tenant movement, authoritative lookup, central
  credential protection, or repeatable multitenant operations matter.
