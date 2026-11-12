# ykgpg

Guided YubiKey OpenPGP setup for fish: an offline certify-only primary key,
[S]/[E]/[A] subkeys on several YubiKeys, a CI-only signing subkey, and renewal.

> **Status: pre-release — Go rewrite in progress.** The original fish
> script is retired to `legacy/ykgpg.fish` as the behavior-parity
> reference; the Go implementation (two client libraries plus the CLI)
> is scaffolded in this repo.

## Install (after the refactor)

```fish
fisher install awol/ykgpg
```

## Commands

| Command                       | What it does                                                          |
| ----------------------------- | --------------------------------------------------------------------- |
| `ykgpg` / `ykgpg walkthrough` | Run every step in order, asking before each one                       |
| `ykgpg prep`                  | Check tools, smart-card daemon, pinentry                              |
| `ykgpg generate`              | Create the key and the encrypted backup (once)                        |
| `ykgpg card`                  | Prepare one YubiKey (PINs, touch, name), write the subkeys            |
| `ykgpg ci`                    | Export the CI signing subkey, write the registry public key           |
| `ykgpg daily`                 | Import the public key into your daily keyring, learn a card           |
| `ykgpg test`                  | Sign and encrypt with each card                                       |
| `ykgpg ssh`                   | Use the [A] subkey for SSH through gpg-agent                          |
| `ykgpg renew`                 | Extend subkey expiry; refresh backup, CI key, registry key            |
| `ykgpg revoke`                | Show / import the revocation certificate from the backup              |
| `ykgpg offline`               | Copy the backup to removable drives (verified), remove the local copy |
| `ykgpg status`                | Backup, key, expiry and card overview                                 |

Every private-key operation happens in a throwaway keyring under
`$XDG_RUNTIME_DIR` (tmpfs where available) that is wiped when the step ends,
on error, or on Ctrl-C. Your daily keyring only ever receives the public key
and card stubs. See the security notes in the implementation plan.

## Requirements

- GnuPG 2.2+ (2.4 recommended); PC/SC (pcscd on Linux, built-in on macOS)
- No shell requirement: a single Go binary, any shell

## Configuration

Environment variables — all optional: `YKGPG_BACKUP`, `YKGPG_ALGO`,
`YKGPG_EXPIRE`, `YKGPG_REGISTRY_KEY`, `YKGPG_STATE_DIR`, `YKGPG_PINENTRY`,
plus per-profile overrides (`YKGPG_EXPIRE_<NAME>`…).

## Development

Tooling is managed with [mise](https://mise.jdx.dev/) and git hooks with
[hk](https://hk.jdx.dev/) (`hk.pkl`): formatting, golangci-lint, go vet,
actionlint, zizmor, taplo — and a security gate (gitleaks on staged
content, a key-material path guard, private-key detection) on every
commit, plus tests and a full-history secret scan on every push. See
[SECURITY.md](SECURITY.md) for what counts as key material and how it is
enforced.

```sh
mise install           # once: Go, linters, gitleaks, hk
mise run hooks         # once: installs the pre-commit/pre-push hooks (mise-aware)

mise run fmt           # gofmt + goimports
mise run lint          # golangci-lint + go vet + actionlint + zizmor
mise run test          # unit tests (no hardware, no cgo)
mise run leaks         # full-history secret scan
mise run check         # all of the above (CI parity)
```

## License

[MIT](LICENSE)
