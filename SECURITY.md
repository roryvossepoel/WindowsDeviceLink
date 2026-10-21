# Security policy

## Supported versions

Security fixes are developed on `main` and, when applicable, released for the latest stable
version. Older stable versions and previews are not guaranteed to receive security fixes.

| Version | Security support |
|---|---|
| Latest stable release | Supported |
| `main` | Active development |
| Older releases and previews | Not supported |

## Report a vulnerability privately

Do not disclose a suspected vulnerability in a public issue, discussion, pull request or
log attachment. Use **Report a vulnerability** on the repository's **Security** tab to open
a private GitHub security advisory.

Include, where possible:

- the affected version, component and execution mode;
- the security impact and required attacker access;
- minimal reproduction steps using fictitious identifiers and credentials;
- sanitized output and a suggested mitigation, if known.

Do not submit live API keys, tokens, client secrets, private keys, certificates, DeviceLink
payloads, association JWTs or customer/device identifiers. If a credential may already be
exposed, revoke or rotate it immediately.

Relevant security areas include authentication and secret handling, cross-tenant isolation,
Backend authorization, unsafe lifecycle or deletion behavior, firmware-state operations and
failures to redact sensitive data.

Reports are assessed on a best-effort basis. Please allow time to reproduce and coordinate
a fix before public disclosure.
