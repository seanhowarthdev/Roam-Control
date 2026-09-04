# Security Policy

## Supported version

Security fixes are currently made against the latest public beta only.

## Reporting a vulnerability

Please use GitHub's **Report a vulnerability** private security-advisory flow when it is available on the repository. Do not post exploitable details in a public issue.

Include concise reproduction steps and the affected version/build. Never attach a real RPPairing file, pairing PIN, certificate, provisioning profile, Apple credential or unredacted diagnostics. A maintainer may ask for additional non-sensitive details privately.

Ordinary crashes, interface problems and connection failures that do not expose sensitive information can use the public bug-report template.

## Sensitive material

Pairing records grant privileged local access to the paired device and must be treated as secrets. Roam Control stores its record in the iPhone Keychain and does not upload it. If a record is ever exposed, remove the pairing in Roam Control and pair the iPhone again.
