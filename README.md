# ykgpg

Guided YubiKey OpenPGP setup for fish: an offline certify-only primary key,
[S]/[E]/[A] subkeys on several YubiKeys, a CI-only signing subkey, and renewal.

> **Status: pre-release.** `functions/ykgpg.fish` is the unmodified v1.0.0
> personal script. The refactor that turns it into a proper plugin is fully
> specified in [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) — work through
> the phases in order. Do not `fisher install` until Phase 7.

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

- fish 3.6+ (uses `fish --no-config`, `path`)
- GnuPG 2.2+ (2.4 recommended), ykman 5.x
- Linux (pcscd) or macOS (built-in PC/SC framework)

## Configuration

Environment variables — all optional: `YKGPG_BACKUP`, `YKGPG_ALGO`,
`YKGPG_EXPIRE`, `YKGPG_REGISTRY_KEY`, `YKGPG_STATE_DIR`, `YKGPG_PINENTRY`.
Personal overrides belong in `~/.config/fish/conf.d/ykgpg.fish` (use `set -gx`).

## Docs

- [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) — the refactor, phase by phase
- [docs/GPG-SIGNING-KEY.md](docs/GPG-SIGNING-KEY.md) — the original design notes / manual walkthrough

## Development

Tooling is managed with [mise](https://mise.jdx.dev/) (installs `hk`,
`actionlint`, `taplo`; fish itself comes from the system) and git hooks with
[hk](https://hk.jdx.dev/) (`hk.pkl`). Fish's dev toolchain is thin: there is
no shellcheck for fish — the lint stack is `fish -n` (syntax),
`fish_indent --check` (formatting), fixture-based tests, and `actionlint`
for the workflow file.

```sh
mise install           # once: hk, actionlint, taplo
mise run hooks         # once: installs the pre-commit hook (mise-aware)

mise run fmt           # fish_indent --write (also auto-run by pre-commit)
mise run lint          # fish -n + fish_indent --check + actionlint + taplo
mise run test          # fixture-based unit tests
mise run leak          # interactive-shell leak regression test
mise run check         # all of the above (CI parity)
```

The pre-commit hook (`hk check`) auto-formats staged `.fish` files, stages
the fix, then runs syntax/format/actionlint/taplo checks and the unit tests.

## License

[MIT](LICENSE)
