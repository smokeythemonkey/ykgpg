# Security Policy

## Reporting

Open a private vulnerability report on GitHub or email the maintainer.
For a bug in key *handling* (key material reaching disk, stderr, or a
commit), include the reproduction and the affected profiles.

## What this project considers secret

| Item | Secret? | Notes |
| --- | --- | --- |
| Backup file (`*.tar.gpg`) | **Yes** | Encrypted, but treat it as the crown jewel: it holds the primary secret key and the revocation certificate. Never commits, never uploads. |
| `secret.asc`, exported secret keys, revocation certificates (`*.rev`, `revoke.asc`) | **Yes** | Plaintext key material or permanent self-destruction tokens. |
| Key passphrase / backup passphrase | **Yes** | They live in pinentry and the password manager; they must never appear in the repo, issues, or logs. |
| YubiKey PINs and the admin PIN | **Yes** | Typed into prompts; never stored by this tool. |
| State files (`*.state`) | Metadata | Fingerprints, UIDs, card serials and labels. Written 0600, but committing them leaks identity and card inventory. |
| Public keys, registry keys | No | Safe to commit or publish. |

## Enforcement

- **pre-commit** (`hk`): `gitleaks protect` on staged content,
  `detect-private-key`, an explicit path guard
  (`scripts/git-guard.sh`) that refuses key-material file names, and a
  large-file check.
- **pre-push**: the same plus the full unit test suite.
- **CI** (`leaks` job): `gitleaks detect` over the *entire git history*
  and `gitleaks dir` over the working tree.
- **`.gitignore`**: a last-resort net for accidental drops (backups,
  stubs, exported keys).

When a pattern in the table above legitimately appears in a test
fixture, it is added to `.gitleaks.toml`'s allowlist in the same commit,
so reviewers see the decision.
