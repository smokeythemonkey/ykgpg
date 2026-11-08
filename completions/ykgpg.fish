# completions/ykgpg.fish — subcommand completions for ykgpg
# Part of the plugin scaffold; the command set (incl. `revoke`) is final.

complete -c ykgpg -f

complete -c ykgpg -s v -l version -d "Print version and exit"
complete -c ykgpg -s h -l help -d "Show help"

complete -c ykgpg -f -a 'walkthrough\tRun every step in order, asking before each one (default)' \
    'prep\tCheck tools, smart-card daemon and pinentry' \
    'generate\tCreate the key and the encrypted backup (once)' \
    'card\tPrepare one YubiKey (PINs, touch, name) and write the subkeys' \
    'ci\tExport the signing subkey for CI, write the registry public key' \
    'daily\tImport the public key into your daily keyring, learn a card' \
    'test\tSign and encrypt with each card' \
    'ssh\tUse the [A] subkey for SSH through gpg-agent' \
    'renew\tExtend subkey expiry; refresh backup, CI key and registry key' \
    'revoke\tShow/import the revocation certificate from the backup' \
    'offline\tCopy the backup to removable drives (verified), remove the local copy' \
    'status\tBackup, key, expiry and card overview' \
    'help\tShow help'
