# Security Policy

## Supported version

| Release | Security support |
|---|---|
| Public Beta v1.0 | Yes |
| Development snapshots and superseded candidates | No |

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could enable arbitrary code execution, unsafe trust-store modification, signature bypass, command injection, privilege escalation, destructive file deletion, or unexpected boot-configuration changes.

Use GitHub's private vulnerability-reporting feature for this repository when available. Include a concise description, affected script and function, preconditions, reproduction steps, expected and actual behavior, potential impact, and a proposed fix when available.

Do not include secrets, recovery keys, private certificates, or unredacted personal data.

## Scope

Security reports should concern original project code or documentation. Vulnerabilities in Windows, PowerShell, WinGet, AMD software, Lenovo software, firmware, SDK/WDK tools, or other third-party products should be reported to their respective vendors.

## Trust model

The toolkit relies on exact hashes, Authenticode signatures, signer identities, hardware IDs, reboot boundaries, live system state, and Windows catalog verification. A proposed change that bypasses or weakens those controls is security-sensitive.
