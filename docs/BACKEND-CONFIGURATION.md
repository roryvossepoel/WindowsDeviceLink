# Backend configuration

The Function App reads one non-secret JSON setting named
`WINDOWSDEVICELINK_CONFIGURATION_JSON`. It defines the allowed tenants and maps each
tenant to an authentication profile. The JSON never contains a certificate, client
secret, token, or private key.

## Shared multitenant application

This is the simplest multitenant backend model. Every tenant uses the same application
and Key Vault-backed credential, while the backend requests a separate token in each
tenant:

```json
{
  "schemaVersion": 1,
  "mode": "Backend",
  "authenticationProfiles": {
    "shared-multitenant-app": {
      "method": "Certificate",
      "clientId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "credentialSetting": "WINDOWSDEVICELINK_GRAPH_CREDENTIAL",
      "certificatePasswordSetting": "WINDOWSDEVICELINK_GRAPH_CERTIFICATE_PASSWORD"
    }
  },
  "tenants": [
    {
      "name": "Tenant Alpha",
      "tenantId": "11111111-1111-1111-1111-111111111111",
      "authenticationProfile": "shared-multitenant-app"
    },
    {
      "name": "Tenant Beta",
      "tenantId": "22222222-2222-2222-2222-222222222222",
      "authenticationProfile": "shared-multitenant-app"
    }
  ]
}
```

The `aaaaaaaa-...` value is an application (client) ID. The `11111111-...` and
`22222222-...` values are tenant IDs. Admin consent for the application permission is
still required in every listed tenant.

## Separate applications per tenant

Tenants can refer to different profiles. Each profile independently selects
`Certificate` or `ClientSecret`, its client ID, and the Function App setting containing
the Key Vault-resolved credential. This is useful when an organization cannot use one
multitenant application. See
[`backend-configuration-tenant-apps.example.json`](../examples/backend-configuration-tenant-apps.example.json).

For a Move, the backend resolves the source and target tenant separately. The source
credential is used for lookup and removal; the target credential is used for lookup,
creation, and verification.

## Credential settings

`credentialSetting` is an application-setting name, not a Key Vault URI or secret
value. For isolation from unrelated Function settings, credential and password setting
names must start with `WINDOWSDEVICELINK_GRAPH_`. Configure the setting as an Azure Key
Vault reference:

```text
WINDOWSDEVICELINK_GRAPH_CREDENTIAL
  = @Microsoft.KeyVault(SecretUri=https://<vault>.vault.azure.net/secrets/<credential>/)
```

For `Certificate`, the resolved value must be a base64-encoded PFX. An optional
`certificatePasswordSetting` can reference the PFX password. For `ClientSecret`, the
resolved credential setting contains the application secret. Certificate authentication
is preferred.

The reference deployment creates `WINDOWSDEVICELINK_GRAPH_CREDENTIAL` and the optional
`WINDOWSDEVICELINK_GRAPH_CERTIFICATE_PASSWORD`. Additional profiles can refer to extra
Key Vault-backed application settings created by the operator. The Function App's
managed identity needs only `secrets/get` access to the referenced values.

## Validation and API boundary

- `schemaVersion` must be integer `1` and `mode` must be `Backend`.
- Tenant IDs and client IDs must be non-empty GUIDs.
- Tenant IDs and names must be unique; every tenant must reference an existing profile.
- Authentication methods are exactly `Certificate` or `ClientSecret`.
- Unknown fields and unsafe application-setting names are rejected.
- `defaultTenantId`, when supplied, must reference a configured tenant.
- Empty or invalid configuration fails closed before a Graph mutation.
- The authenticated tenant catalog returns tenant names, IDs, and capabilities only.
  It never exposes profile names, client IDs, setting names, or credentials.

The existing `WINDOWSDEVICELINK_API_KEY` remains independent and protects calls from
the module or another client to the Function backend.
