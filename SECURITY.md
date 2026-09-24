# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email [harsh.julapelli@gmail.com](mailto:harsh.julapelli@gmail.com) with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
3. You will receive a response within 48 hours

## Security Design

This toolkit follows operational security best practices:

- **No hardcoded secrets** — Scripts accept credentials via `SecureString`, PSCredential, or Azure Key Vault references
- **Least privilege** — Remote operations use scoped WinRM/PowerShell Remoting; Azure modules use managed identity where possible
- **PAT handling** — Azure DevOps PATs are passed as `SecureString` parameters, never written to logs or disk
- **RBAC-first Bicep** — Key Vault modules enable `enableRbacAuthorization`; no shared access keys
- **TLS enforcement** — `Invoke-TlsAudit.ps1` validates TLS 1.2+ and flags weak cipher suites
- **Compliance baselines** — `Test-ComplianceBaseline.ps1` checks servers against a security baseline

## Secure Usage Guidelines

- Run remote scripts from a hardened jump host, not a workstation
- Store PATs and service credentials in Azure Key Vault or a secrets manager, not plaintext
- Review `WhatIf` output before executing state-changing operations (rolling restarts, cert installs)
- Rotate service account credentials regularly using `Invoke-SecretRotation.ps1`

## Sensitive Data

- Never commit credential files, PFX certificates, or `.env` files
- The `.gitignore` excludes common secret file patterns
- Certificate passwords are always `SecureString`; PFX files are removed from remote hosts after import
