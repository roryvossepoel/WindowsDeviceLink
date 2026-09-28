# Authentication and deployment security

## Supported routes

| Route | UI and CLI | Credential handling |
|---|---|---|
| Direct Interactive | Operator sign-in on Windows through Microsoft Graph/WAM | Delegated session; no app secret |
| Direct DeviceCode | Operator sign-in, including WinPE when tenant policy permits | Delegated token retained only for the session/operation |
| Backend API | Operator or unattended provisioning | API key supplied at runtime; Graph credentials remain in the backend |

DeviceLink generation and local firmware operations execute on the target device in
WinPE or Windows/OOBE. The backend performs cloud operations; it does not generate
the target device's local identity. The low-level Webhook registration transport is
also an API route.

## Recommended hardening for API deployments

These are deployment recommendations, not features that WindowsDeviceLink provisions
or enforces. Each organization owns its infrastructure and credential lifecycle.

- Restrict the Function App to the public NAT/egress IP addresses of trusted provisioning
  networks and deny other sources. Apply equivalent restrictions to any endpoint that
  distributes bootstrap configuration or credentials. Network restrictions supplement
  authentication and do not identify individual devices.
- Do not embed API keys, Graph secrets or private keys in WinPE images, public scripts,
  repositories, command-line examples or logs. Supply credentials at execution time
  through an appropriately protected organizational mechanism. A secret URL is not
  access control. Runtime delivery still places the credential on the device temporarily.
- Use HTTPS and send the key in the `X-WindowsDeviceLink-Key` request header. The supplied
  backend validates this against `WINDOWSDEVICELINK_API_KEY`. This is a custom application
  secret, not an Azure Functions host/function key. Rotating an Azure Function key does
  not rotate this secret. The supplied HTTP triggers use anonymous platform auth because
  the request handler performs the custom key check.
- Rotate the application API secret periodically and immediately on suspected compromise.
  Update the backend configuration and the protected distribution mechanism together.
  Daily rotation is a possible organizational policy, not a module requirement or a
  universal standard. The supplied backend accepts one configured key; it does not
  implement dual-key overlap or automatic expiry. Active clients must obtain the new key.
  A deployment requiring overlapping keys or disruption-free rotation must provide that
  mechanism separately and verify its revocation behavior.
- If an organization adds Azure platform key authentication, never distribute `_master`;
  use the narrowest available scope. Platform authentication requires coordinated client
  and server configuration and is not interchangeable with the custom API header.
- Enforce allowed tenants and actions on the server. A selector in the UI is not an
  authorization boundary. Record request IDs and operation outcomes without secrets.

Bootstrap services, key distribution, rotation jobs, networking and identity-based API
access are outside the module's scope. Organizations may implement additional controls.
We do not claim that a shared API key plus an IP allowlist authenticates a specific operator.

## Session and error handling

Public Direct methods accept only Interactive and DeviceCode. Public certificate,
client-secret, environment-credential, managed-identity and access-token inputs are
removed. Existing SDK contexts must be delegated before Direct registration is allowed.
Private token transport remains necessary for reuse after DeviceCode operator sign-in;
it is not a public automation authentication route.

The module must not expose bearer tokens, API keys or raw DeviceLink payloads in normal
logs, errors or returned metadata. DeviceCode user codes are intentionally shown to the
operator; OAuth device codes remain sensitive. Do not publish active sign-in codes.

A failed lookup is Unknown, never proof of NotAssociated. Mutations are not blindly
retried: a timeout can occur after the server committed an operation.

## Validation

Offline regression tests use synthetic credentials and mocked HTTP. Hardware smoke
tests must separately verify Windows/OOBE and WinPE behavior before release. Backend
credential handling is independent of the restricted Direct client surface.

## Microsoft references

- [Securing Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/security-concepts)
- [Function access keys and rotation](https://learn.microsoft.com/en-us/azure/azure-functions/function-keys-how-to)
- [Azure Functions networking options](https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options)
