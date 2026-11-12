#!/usr/bin/env fish
# ykgpg — guided YubiKey OpenPGP setup: offline certify-only primary key,
# [S]/[E]/[A] subkeys on several YubiKeys, a CI-only signing subkey, renewal.
# Companion to GPG-SIGNING-KEY.md. Requires fish 3.4+, GnuPG 2.2+ (2.4
# recommended), ykman 5.x, pcscd.
#
# Every private-key operation happens in a throwaway keyring under
# $XDG_RUNTIME_DIR (tmpfs) that is wiped when the step ends, on error, or on
# Ctrl-C. Your daily keyring only ever receives the public key and card stubs.

set -g YKGPG_VERSION 1.1.0

# ---- configuration (override with environment variables) --------------------
# Defaults below apply to every profile. Backup and registry-key paths are
# per-profile (see _resolve_profile): "personal" keeps the legacy file names,
# any other profile derives them from its name (~/backups/<name>.tar.gpg,
# ~/<name>-signing-key.asc). Per-profile overrides: any of the variables
# below with _<NAME> appended (profile uppercased, dashes to underscores),
# e.g. YKGPG_EXPIRE_FORWARDEMAIL=1y.
set -g YKGPG_PROFILE_DEFAULT personal
set -q YKGPG_ALGO; or set -g YKGPG_ALGO rsa4096
set -q YKGPG_EXPIRE; or set -g YKGPG_EXPIRE 2y
if not set -q YKGPG_STATE_DIR
    if set -q XDG_STATE_HOME
        set -g YKGPG_STATE_DIR $XDG_STATE_HOME/ykgpg
    else
        set -g YKGPG_STATE_DIR $HOME/.local/state/ykgpg
    end
end
# YKGPG_PINENTRY: optional pinentry-program for the throwaway keyrings.
# YKGPG_PROFILE: profile to use when no -p flag is passed.

# Remember the daily keyring so it can be restored after each throwaway step.
if set -q GNUPGHOME
    set -g _daily_home $GNUPGHOME
    set -g _daily_home_from_env 1
else
    set -g _daily_home $HOME/.gnupg
    set -g _daily_home_from_env 0
end

# ---- output helpers ---------------------------------------------------------
function _header
    echo
    set_color --bold brblue
    echo "━━ $argv"
    set_color normal
end

function _say
    set_color brblue
    echo -n '==> '
    set_color normal
    echo $argv
end

function _ok
    set_color green
    echo -n '  ✓ '
    set_color normal
    echo $argv
end

function _warn
    set_color yellow
    echo -n '  ! ' >&2
    set_color normal
    echo $argv >&2
end

function _die
    set_color red
    echo -n '  ✗ ' >&2
    set_color normal
    echo $argv >&2
    exit 1
end

# _confirm "question" [y|n]  → status 0 for yes
function _confirm --argument-names question default
    test -n "$default"; or set default n
    set -l hint '[y/N]'
    test "$default" = y; and set hint '[Y/n]'
    while true
        read -l -P "$question $hint " ans; or _die Aborted.
        test -z "$ans"; and set ans $default
        switch (string lower -- $ans)
            case y yes
                return 0
            case n no
                return 1
        end
    end
end

# _ask "prompt" [default]  → answer in $REPLY
function _ask --argument-names prompt default
    set -l p $prompt
    test -n "$default"; and set p "$p [$default]"
    read -l -P "$p: " ans; or _die Aborted.
    test -z "$ans"; and set ans $default
    set -g REPLY $ans
end

function _pause
    read -l -P (set_color brblack)"Press Enter to continue…"(set_color normal) _unused; or true
end

function _fmt_date --argument-names epoch
    date -d @$epoch +%F 2>/dev/null; or date -r $epoch +%F
end

# ---- profiles (key identities) ----------------------------------------------
# A profile is one key identity: its own primary key, subkeys, state file,
# encrypted backup and registry public key. "personal" (the default) is the
# S/E/A-subkeys-on-YubiKeys setup this script has always managed; any other
# profile is a software-only release key (sign-only subkey by default, its
# private half only ever inside its own encrypted backup).

function _profile_is_valid --argument-names profile
    string match -qr '^[a-z0-9][a-z0-9_-]*$' -- $profile
end

# Profiles ever created (one per line). Only feeds the accidental-fork guard
# in step_generate; state stays expendable without it.
function _profiles_list
    test -f $YKGPG_STATE_DIR/profiles; and cat $YKGPG_STATE_DIR/profiles
end

function _profile_record --argument-names profile
    mkdir -p $YKGPG_STATE_DIR
    chmod 700 $YKGPG_STATE_DIR
    contains -- $profile (_profiles_list); and return 0
    echo $profile >>$YKGPG_STATE_DIR/profiles
end

# One-time move of the pre-profile flat state file to personal.state.
function _migrate_legacy_state
    if test -f $YKGPG_STATE_DIR/state; and not test -f $YKGPG_STATE_DIR/personal.state
        mv $YKGPG_STATE_DIR/state $YKGPG_STATE_DIR/personal.state
        _profile_record personal
        _ok "Legacy state file moved to $YKGPG_STATE_DIR/personal.state"
    end
end

# Resolve every profile-dependent path/config into globals. Called once at
# the top of main (and per profile by step_status), before any step runs.
function _resolve_profile --argument-names profile
    set -g PROFILE $profile
    set -g _state_file $YKGPG_STATE_DIR/$PROFILE.state
    set -l uc (string upper -- (string replace -a -- - _ $PROFILE))

    # Remember what the user supplied, so repeated resolutions don't inherit
    # a previously derived default.
    if not set -q _user_backup
        if set -q YKGPG_BACKUP
            set -g _user_backup $YKGPG_BACKUP
        else
            set -g _user_backup ""
        end
    end
    if not set -q _user_registry_key
        if set -q YKGPG_REGISTRY_KEY
            set -g _user_registry_key $YKGPG_REGISTRY_KEY
        else
            set -g _user_registry_key ""
        end
    end

    set -l v (string join _ YKGPG_BACKUP $uc)
    if set -q $v
        eval "set -g YKGPG_BACKUP \$$v"
    else if test -n "$_user_backup"
        set -g YKGPG_BACKUP $_user_backup
    else if test $PROFILE = personal
        set -g YKGPG_BACKUP $HOME/backups/awolkey.tar.gpg
    else
        set -g YKGPG_BACKUP $HOME/backups/$PROFILE.tar.gpg
    end

    set -l v (string join _ YKGPG_REGISTRY_KEY $uc)
    if set -q $v
        eval "set -g YKGPG_REGISTRY_KEY \$$v"
    else if test -n "$_user_registry_key"
        set -g YKGPG_REGISTRY_KEY $_user_registry_key
    else if test $PROFILE = personal
        set -g YKGPG_REGISTRY_KEY $HOME/awol-signing-key.asc
    else
        set -g YKGPG_REGISTRY_KEY $HOME/$PROFILE-signing-key.asc
    end

    set -l v (string join _ YKGPG_ALGO $uc)
    if set -q $v
        eval "set -g YKGPG_ALGO \$$v"
    end
    set -l v (string join _ YKGPG_EXPIRE $uc)
    if set -q $v
        eval "set -g YKGPG_EXPIRE \$$v"
    end
end

function _require_personal --argument-names cmd
    test $PROFILE = personal; and return 0
    _die "'$cmd' applies to the personal key only. Release keys are software-only (their private half lives in their backup). For a release key: ykgpg -p <name> generate, then ci and offline."
end

# ---- state (non-secret: fingerprint, expiry, card serials) ------------------
function _state_get --argument-names key
    test -f $_state_file; or return 1
    string match -rg -- "^$key=(.*)\$" <$_state_file | tail -n 1
end

function _state_set --argument-names key value
    mkdir -p $YKGPG_STATE_DIR
    chmod 700 $YKGPG_STATE_DIR
    set -l lines
    test -f $_state_file; and set lines (string match -v -- "$key=*" <$_state_file)
    printf '%s\n' $lines "$key=$value" >$_state_file
end

function _state_clear_cards
    test -f $_state_file; or return 0
    set -l lines (string match -v -- 'card.*' <$_state_file)
    printf '%s\n' $lines >$_state_file
end

function _state_cards
    test -f $_state_file; or return 0
    string match -- 'card.*' <$_state_file | string replace -r '^card\.' ''
end

# ---- keyrings ---------------------------------------------------------------
function _use_daily_keyring
    if test $_daily_home_from_env = 1
        set -gx GNUPGHOME $_daily_home
    else
        set -e GNUPGHOME
    end
end

function _new_keyring
    _wipe_keyring
    set -l base $XDG_RUNTIME_DIR
    if test -z "$base"; or not test -d "$base"
        set base /dev/shm
        _warn "XDG_RUNTIME_DIR is not set; using $base"
    end
    set -gx WORK (mktemp -d -p $base ykgpg.XXXXXX); or _die "mktemp failed"
    chmod 700 $WORK
    set -gx GNUPGHOME $WORK/gnupg
    mkdir -m 700 $GNUPGHOME
    if set -q YKGPG_PINENTRY
        echo "pinentry-program $YKGPG_PINENTRY" >$GNUPGHOME/gpg-agent.conf
    end
    # Route scdaemon through pcscd (same backend ykman uses). The internal
    # CCID driver cannot reach the card while pcscd serves it.
    echo disable-ccid >$GNUPGHOME/scdaemon.conf
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
end

function _wipe_keyring
    if set -q WORK; and string match -q -- '*/ykgpg.*' $WORK; and test -d $WORK
        gpgconf --homedir $WORK/gnupg --kill all >/dev/null 2>/dev/null
        rm -rf -- $WORK
    end
    set -e WORK
    _kill_scdaemons
    _use_daily_keyring
end

function _ykgpg_cleanup --on-event fish_exit
    _wipe_keyring
end

function _ykgpg_signal --on-signal INT --on-signal TERM --on-signal HUP
    echo >&2
    _warn "Interrupted — wiping the throwaway keyring."
    exit 130
end

function _restore_keyring
    _need_backup
    _new_keyring
    _say "Decrypting the backup — enter the BACKUP passphrase."
    gpg --quiet --decrypt $YKGPG_BACKUP | tar -C $WORK -xf -
    set -l st $pipestatus
    test "$st" = "0 0"; or _die "Could not decrypt/extract the backup"
    _say "Importing the key — gpg may ask for the KEY passphrase."
    gpg --quiet --import $WORK/backup/secret.asc; or _die "Importing the secret key failed"
    gpg --quiet --import-ownertrust $WORK/backup/ownertrust.txt 2>/dev/null
    set -g FPR (_primary_fpr)
    test -n "$FPR"; or _die "No key found in the backup"
    set -l known (_state_get fpr)
    if test -n "$known"; and test "$known" != "$FPR"
        _warn "Backup holds $FPR, but the recorded key is $known"
    end
    # Self-heal: a successful restore re-records the key in this profile's
    # state, so a deleted state file recovers on the next ci/renew/card run
    # (daily does the same for the personal key).
    if test -z "$known"; or test "$known" = "$FPR"
        _state_set fpr $FPR
        _state_set profile $PROFILE
        _profile_record $PROFILE
        set -l uid (gpg --with-colons --list-keys $FPR 2>/dev/null | awk -F: '$1=="uid"{print $10; exit}')
        test -z "$uid"; or _state_set uid $uid
    end
end

# ---- key inspection ---------------------------------------------------------
function _primary_fpr
    gpg --with-colons --list-keys $argv 2>/dev/null | awk -F: '$1=="pub"{p=1;next} p && $1=="fpr"{print $10; exit}'
end

# One line per subkey, in --edit-key order: "index caps fpr validity expiry"
function _subkeys
    gpg --with-colons --list-keys $FPR 2>/dev/null | awk -F: '
        $1=="pub" {want=0}
        $1=="sub" {n++; v=$2; cap=$12; ex=($7==""?"-":$7); want=1; next}
        $1=="fpr" && want {print n, cap, $10, v, ex; want=0}'
end

# Newest non-revoked subkey with capability s, e or a
function _subkey_fpr --argument-names cap
    _subkeys | awk -v c=$cap '$4!="r" && index($2,c) {f=$3} END {if (f) print f}'
end

function _expiry_epoch
    _subkeys | awk '$4!="r" && $5!="-" {print $5}' | sort -n | head -n 1
end

# ---- cards ------------------------------------------------------------------
# Kill every scdaemon, plus gpg processes of throwaway homes left over from
# crashed earlier runs (their homes are gone, so gpgconf cannot reach them).
# A stray scdaemon still on the internal CCID driver claims the USB interface
# exclusively and blocks every pcscd-backed access to the reader.
function _kill_scdaemons
    if set -q GNUPGHOME; and test -n "$GNUPGHOME"
        gpgconf --homedir $GNUPGHOME --kill scdaemon >/dev/null 2>/dev/null
    end
    gpgconf --homedir $_daily_home --kill scdaemon >/dev/null 2>/dev/null
    for p in (pgrep -f 'ykgpg\.' 2>/dev/null)
        switch (ps -o comm= -p $p 2>/dev/null)
            case gpg-agent scdaemon
                kill $p 2>/dev/null
        end
    end
    true
end

function _release_card
    _kill_scdaemons
end

function _require_one_card
    while true
        set -l s (ykman list --serials 2>/dev/null)
        switch (count $s)
            case 1
                set -g CARD_SERIAL $s[1]
                return 0
            case 0
                _warn "No YubiKey detected."
            case '*'
                _warn "Several YubiKeys detected ("(string join ', ' $s)"). Leave only one inserted."
        end
        _confirm "Retry?" y; or return 1
    end
end

# Three elements: sig enc aut fingerprints on the inserted card, "-" if empty
function _card_slots
    set -l raw (gpg --card-status --with-colons 2>/dev/null)
    if test $status -ne 0
        # a stray scdaemon may hold the reader; kill it and retry once
        _kill_scdaemons
        sleep 0.5
        set raw (gpg --card-status --with-colons 2>&1)
        test $status -eq 0; or begin
            printf '%s\n' $raw >&2
            return 1
        end
    end
    printf '%s\n' $raw | awk -F: '
        $1=="fpr" {for (i=2; i<=4; i++) {f=toupper($i); if (f=="" || f ~ /^0+$/) f="-"; print f}; exit}'
end

function _verify_card
    set -l slots (_card_slots)
    test (count $slots) -eq 3; or return 1
    set -l names sig enc aut
    set -l bad 0
    for e in $argv
        set -l p (string split : -- $e)
        if test "$slots[$p[1]]" = "$p[2]"
            _ok "$names[$p[1]] slot holds $p[2]"
        else
            _warn "$names[$p[1]] slot: expected $p[2], card has $slots[$p[1]]"
            set bad 1
        end
    end
    test $bad = 0
end

function _learn_card
    _release_card
    _require_one_card; or return 1
    gpg-connect-agent "scd serialno" "learn --force" /bye >/dev/null 2>&1
    gpg --card-status >/dev/null 2>&1; or begin
        _warn "gpg cannot read card $CARD_SERIAL"
        return 1
    end
    _ok "Using YubiKey $CARD_SERIAL"
end

# ---- backup -----------------------------------------------------------------
function _write_backup
    set -l bk $WORK/backup
    mkdir -p $bk
    chmod 700 $bk
    _say "Exporting the secret key — enter the KEY passphrase if asked."
    gpg --armor --export-secret-keys $FPR >$bk/secret.asc; or _die "Exporting the secret key failed"
    gpg --armor --export $FPR >$bk/public.asc
    gpg --export-ownertrust >$bk/ownertrust.txt
    if test -f $GNUPGHOME/openpgp-revocs.d/$FPR.rev
        cp $GNUPGHOME/openpgp-revocs.d/$FPR.rev $bk/revoke.asc
    else if not test -f $bk/revoke.asc
        _warn "No revocation certificate found to include"
    end

    mkdir -p (dirname $YKGPG_BACKUP)
    set -l tmp $YKGPG_BACKUP.new
    _say "Encrypting the backup — enter the BACKUP passphrase (not the key passphrase)."
    tar -C $WORK -cf - backup | gpg --symmetric --cipher-algo AES256 --yes --output $tmp
    set -l st $pipestatus
    if test "$st" != "0 0"
        rm -f $tmp
        _die "Encrypting the backup failed"
    end
    chmod 600 $tmp
    if test -f $YKGPG_BACKUP
        set -l old $YKGPG_BACKUP.(date +%Y%m%d-%H%M%S).old
        mv $YKGPG_BACKUP $old
        _warn "Previous backup kept as $old — shred it once the new one is verified and copied offline."
    end
    mv $tmp $YKGPG_BACKUP
    _ok "Backup written to $YKGPG_BACKUP"
end

# Capability list this profile was generated with ("sign encr auth" or a
# subset). Falls back to the profile's default when the state file predates
# profiles or was rebuilt without the subkeys entry.
function _profile_caps
    set -l caps
    set -l raw (_state_get subkeys)
    test (count $raw) -gt 0; and set caps (string split ' ' -- $raw)
    if test (count $caps) -eq 0
        if test $PROFILE = personal
            set caps sign encr auth
        else
            set caps sign
        end
    end
    for c in $caps
        echo $c
    end
end

# Primary + one secret key per capability: how many secret keys a healthy
# backup of this profile must hold.
function _expected_secret_count
    math 1 + (count (_profile_caps))
end

function _verify_backup --argument-names expected
    _header "Verifying the backup"
    _restore_keyring
    test "$FPR" = "$expected"; or _die "Restored key $FPR does not match $expected"
    set -l info (gpg --with-colons --list-secret-keys $FPR | awk -F: '
        $1=="sec" || $1=="ssb" {n++; if ($15 != "" && $15 != "+") stub++}
        END {print n+0, stub+0}')
    set -l parts (string split ' ' -- $info)
    test $parts[2] -eq 0; or _die "The backup contains card stubs instead of real secret keys"
    set -l need (_expected_secret_count)
    test $parts[1] -ge $need; or _die "The backup holds $parts[1] secret keys; expected at least $need"
    _wipe_keyring
    _ok "Backup restores: $parts[1] secret keys (primary + subkeys)"
end

# Writable mount points of removable drives (udisks mounts them here)
function _removable_dirs
    for d in /run/media/$USER/* /media/$USER/*
        test -d $d; and test -w $d; and echo $d
    end
end

function _is_local_path --argument-names file
    string match -q -- "$HOME/*" (path resolve -- $file)
end

# Use YKGPG_BACKUP if it exists, otherwise look for the same file name on
# mounted removable drives. Sets YKGPG_BACKUP on success.
function _find_backup
    test -f $YKGPG_BACKUP; and return 0
    set -l name (basename $YKGPG_BACKUP)
    set -l found
    for d in (_removable_dirs)
        test -f $d/$name; and set -a found $d/$name
    end
    switch (count $found)
        case 0
            return 1
        case 1
            set -g YKGPG_BACKUP $found[1]
        case '*'
            _say "Backups found on several drives:"
            for i in (seq (count $found))
                echo "  $i) $found[$i]"
            end
            while true
                _ask "Which one" 1
                if string match -qr '^[0-9]+$' -- $REPLY; and test $REPLY -ge 1; and test $REPLY -le (count $found)
                    break
                end
                _warn "Pick a number from the list"
            end
            set -g YKGPG_BACKUP $found[$REPLY]
    end
    _ok "Using backup: $YKGPG_BACKUP"
end

function _need_backup
    _find_backup; and return 0
    _die "No backup at $YKGPG_BACKUP and none on mounted drives — plug in the backup drive, or set YKGPG_BACKUP to its path"
end

# Copy the backup to removable drives, verify each copy, then offer to remove
# the copy on this machine.
function step_offline
    _header "Store the backup offline"
    _need_backup
    set -l src (path resolve -- $YKGPG_BACKUP)
    set -l name (basename $src)
    set -l sum (sha256sum $src | string split -f1 ' ')
    set -l copies
    _is_local_path $src; or set -a copies $src
    _say "Keep at least two copies on separate drives, one of them stored somewhere else."
    _say "The backup is encrypted, but it is your only copy of the primary key."
    _say "Backups of several identities can share a drive — one file per profile."

    while true
        set -l prompt "Copy the backup to a drive now?"
        test (count $copies) -gt 0; and set prompt "Copy it to another drive? ("(count $copies)" verified so far)"
        set -l def y
        test (count $copies) -ge 2; and set def n
        _confirm $prompt $def; or break

        set -l suggest
        for d in (_removable_dirs)
            set -l dest (path resolve -- $d/$name)
            contains -- $dest $copies; and continue
            set suggest $d
            break
        end
        set -l mounted (_removable_dirs)
        test (count $mounted) -gt 0; and _say "Mounted drives: "(string join ', ' $mounted)
        _ask "Destination directory" "$suggest"
        set -l dir $REPLY
        if not test -d "$dir"; or not test -w "$dir"
            _warn "Not a writable directory: $dir"
            continue
        end
        set -l dest (path resolve -- $dir/$name)
        if test "$dest" = "$src"
            _ok "That is the source file itself"
            continue
        end
        if test -e $dest; and not _confirm "$dest exists. Overwrite it?" n
            continue
        end
        cp $src $dest.partial; or begin
            _warn "Copy failed"
            continue
        end
        sync
        if test (sha256sum $dest.partial | string split -f1 ' ') = "$sum"
            mv $dest.partial $dest
            chmod 600 $dest
            sync
            set -a copies $dest
            _ok "Copied and verified: $dest"
            _say "Eject the drive before unplugging it."
        else
            rm -f $dest.partial
            _warn "Checksum mismatch on $dest — copy discarded"
        end
    end

    _say (count $copies)" verified offline cop"(test (count $copies) -eq 1; and echo y; or echo ies)
    for c in $copies
        echo "      $c"
    end

    if _is_local_path $src
        if test (count $copies) -ge 2
            if _confirm "Remove the copy on this machine ($src)?" y
                if command -q shred
                    shred -u $src
                else
                    rm -f $src
                end
                and _ok "Removed $src"
                rmdir (dirname $src) 2>/dev/null
                set -g YKGPG_BACKUP $copies[1]
                _say "On SSDs and copy-on-write filesystems, shred can't guarantee the old blocks are gone; the file was encrypted, so that's acceptable."
            end
        else
            _warn "Keep the copy on this machine until you have two offline copies; then run: ykgpg offline"
        end
    end
    _say "Next time, plug in a backup drive before running ykgpg; it finds the file on mounted drives."
end

# ---- CI export --------------------------------------------------------------
function _ci_export
    set -l sig (_subkey_fpr s)
    test -n "$sig"; or _die "No signing subkey found"
    _say "Signing subkey: $sig"
    _say "Set a CI-ONLY passphrase: old = KEY passphrase, new = CI passphrase (this becomes GPG_PASS)."
    _say "This only changes the throwaway copy; the backup keeps the real key passphrase."
    gpg --passwd $FPR; or _die "Changing the passphrase failed"

    set -l armored (gpg --armor --export-secret-subkeys "$sig!" | string collect)
    test -n "$armored"; or _die "Exporting the signing subkey failed"
    set -l found (printf '%s\n' $armored | gpg --show-keys --with-colons 2>/dev/null | awk -F: '
        $1=="ssb" {w=1; next}
        w && $1=="fpr" {print $10; w=0}')
    test "$found" = "$sig"; or _die "Export check failed: expected only $sig, got: $found"
    _ok "Export contains only the signing subkey"

    gpg --armor --export "$sig!" >$YKGPG_REGISTRY_KEY
    _ok "Registry public key (primary + signing subkey) written to $YKGPG_REGISTRY_KEY"
    _deliver_ci_key $armored
    _say "GPG_FINGERPRINT = $FPR"
end

function _deliver_ci_key --argument-names armored
    _header "Deliver the CI signing subkey"
    _say "Store these three in BWS (or your secret store): GPG_PRIVATE_KEY = the block below, GPG_PASS = the CI passphrase, GPG_FINGERPRINT = $FPR"
    echo "  1) Copy to the clipboard"
    echo "  2) Print to this terminal"
    echo "  3) Skip"
    _ask Choice 1
    switch $REPLY
        case 1
            if command -q wl-copy; and set -q WAYLAND_DISPLAY
                printf '%s\n' $armored | wl-copy
                _ok "Copied. Paste it into BWS as GPG_PRIVATE_KEY."
                _pause
                wl-copy --clear
                _ok "Clipboard cleared"
            else if command -q xclip
                printf '%s\n' $armored | xclip -selection clipboard
                _ok "Copied. Paste it into BWS as GPG_PRIVATE_KEY."
                _pause
                printf '' | xclip -selection clipboard
                _ok "Clipboard cleared"
            else
                _warn "No clipboard tool found (wl-copy or xclip)"
                _deliver_ci_key $armored
            end
        case 2
            printf '%s\n' $armored
            _warn "Clear your terminal scrollback after copying it."
        case 3
            _warn "Skipped. Re-run later with: ykgpg -p $PROFILE ci"
        case '*'
            _deliver_ci_key $armored
    end
end

# ---- steps ------------------------------------------------------------------
function step_prep
    _header "0. Host checks"
    set -l missing
    for t in gpg gpgconf gpg-connect-agent ykman tar awk mktemp
        if command -q $t
            _ok $t
        else
            set -a missing $t
            _warn "$t not found"
        end
    end
    test (count $missing) -eq 0; or _die "Install the missing tools first: $missing"

    # scdaemon is a separate package on Ubuntu and its binary is not on
    # PATH (/usr/lib/gnupg/scdaemon), so ask gpgconf whether it exists.
    if gpgconf --list-components 2>/dev/null | string match -qr '^scdaemon:'
        _ok scdaemon
    else
        _die "scdaemon is not installed — gpg cannot see any OpenPGP card (sudo apt install scdaemon)"
    end

    set -l gv (gpg --version | string match -rg '^gpg \(GnuPG\) (\S+)')
    string match -qr '^2\.([2-9]|[1-9][0-9])\.' -- $gv
    and _ok "GnuPG $gv"
    or _warn "GnuPG $gv — 2.2+ required, 2.4 recommended"

    set -l yv (ykman --version 2>/dev/null | string match -rg 'version:? (\S+)')
    string match -qr '^([5-9]|[1-9][0-9])\.' -- $yv
    and _ok "ykman $yv"
    or _die "ykman $yv — this script needs ykman 5.x command names"

    command -q pinentry; and _ok pinentry
    or _warn "pinentry not found — install pinentry-curses or pinentry-gnome3"

    if command -q systemctl
        if systemctl is-active --quiet pcscd.socket; or systemctl is-active --quiet pcscd.service
            _ok "pcscd is running"
        else if _confirm "pcscd is not running. Run: sudo systemctl enable --now pcscd?" y
            sudo systemctl enable --now pcscd; or _die "Could not start pcscd"
            _ok "pcscd enabled"
        else
            _warn "Smart-card access will most likely fail without pcscd"
        end
    end

    set -l cards (ykman list --serials 2>/dev/null)
    test (count $cards) -gt 0; and _ok "YubiKey(s) detected: "(string join ', ' $cards)

    # gpg must actually be able to read a present card; ykman seeing it is
    # not enough (different backends).
    if test (count $cards) -gt 0
        if gpg --card-status >/dev/null 2>&1 </dev/null
            _ok "gpg can read the card"
        else
            # a stray scdaemon (e.g. from a crashed earlier run) may hold
            # the reader; kill them all and retry once before blaming the
            # CCID backend
            _kill_scdaemons
            sleep 0.5
            if gpg --card-status >/dev/null 2>&1 </dev/null
                _ok "gpg can read the card (after clearing stray scdaemons)"
            else
                _die "gpg cannot read the card while ykman can — scdaemon's CCID backend conflicts with pcscd. Fix: 'echo disable-ccid >> ~/.gnupg/scdaemon.conf'"
            end
        end
    end
    true
end

function step_generate
    _header "1. Generate the key and the encrypted backup"
    if _find_backup
        _warn "A backup already exists: $YKGPG_BACKUP"
        _confirm "Create a NEW key anyway? (the old backup is kept as .old)" n; or return 0
    else if test -n "$(_state_get fpr)"
        _warn "Key "(_state_get fpr)" was already created, but its backup isn't here — is the backup drive plugged in?"
        _confirm "Create a NEW key anyway?" n; or return 0
    else
        # Fork guard: while the backup drive is unplugged, the state file is
        # the only record that this profile's key exists. Without this, a
        # deleted state file would make generate quietly create a second key.
        set -l evidence
        contains -- $PROFILE (_profiles_list)
            and set -a evidence "a $PROFILE key was created before"
        if test $PROFILE = personal; and gpg --list-secret-keys >/dev/null 2>&1
            set -a evidence "your daily keyring already holds secret keys"
        end
        if test (count $evidence) -gt 0
            _warn (string join '; ' $evidence)" — the state file is missing; the old backup may be on an unplugged drive."
            _confirm "Create a NEW key anyway?" n; or return 0
        end
    end
    set -l caps
    if test $PROFILE = personal
        set caps sign encr auth
    else if _confirm "Add only a signing subkey (recommended for release keys)?" y
        set caps sign
    else
        set caps sign encr auth
    end
    _ask Name (git config --get user.name 2>/dev/null)
    set -l name $REPLY
    _ask Email (git config --get user.email 2>/dev/null)
    set -l email $REPLY
    test -n "$name"; and test -n "$email"; or _die "Name and email are required"

    _new_keyring
    _say "Creating the primary key ($YKGPG_ALGO, certify-only, no expiry)."
    _say "pinentry asks for the KEY passphrase — make it strong and store it in Bitwarden."
    gpg --quiet --quick-generate-key "$name <$email>" $YKGPG_ALGO cert never; or _die "Key generation failed"
    set -g FPR (_primary_fpr)
    test -n "$FPR"; or _die "Could not find the new key"
    _ok "Primary key: $FPR"

    for usage in $caps
        _say "Adding the $usage subkey ($YKGPG_ALGO, expires in $YKGPG_EXPIRE)…"
        gpg --quiet --quick-add-key $FPR $YKGPG_ALGO $usage $YKGPG_EXPIRE
        or _die "Adding the $usage subkey failed"
    end
    gpg --list-secret-keys $FPR

    _write_backup

    if command -q paperkey; and _confirm "Make a paper copy with paperkey?" n
        if command -q lpr; and _confirm "Send it to the default printer (lpr)?" y
            gpg --export-secret-keys $FPR | paperkey | lpr; and _ok "Sent to the printer"
        else
            gpg --export-secret-keys $FPR | paperkey
            _warn "Copy it down, then clear your terminal scrollback."
        end
    end

    set -l e (_expiry_epoch)
    _state_clear_cards
    _state_set fpr $FPR
    _state_set uid "$name <$email>"
    _state_set expires $e
    _state_set subkeys (string join ' ' -- $caps)
    _state_set profile $PROFILE
    _profile_record $PROFILE
    _wipe_keyring

    _verify_backup $FPR
    step_offline
    _ok "Key $FPR created ($PROFILE profile)"
    if test $PROFILE != personal
        _say "This key is software-only: it never touches a YubiKey or the daily keyring."
        _confirm "Export the signing subkey for CI now?" y; and step_ci
    end
    _say "Subkeys expire "(_fmt_date $e)". Set a reminder for "(_fmt_date (math --scale=0 "$e - 60 * 86400"))" to run: ykgpg -p $PROFILE renew"
end

function step_card
    _header "Set up a YubiKey"
    _require_personal card
    _need_backup
    _wipe_keyring
    _release_card
    _require_one_card; or return 1
    set -l serial $CARD_SERIAL
    set -l label (_state_get card.$serial)
    if test -z "$label"
        _ask "Label for YubiKey $serial (active, portable, backup…)" ""
        set label $REPLY
    end
    _say "Working on YubiKey $serial ($label)"
    ykman --device $serial openpgp info; or _die "ykman cannot talk to the card (is pcscd running?)"

    # Existing keys
    _release_card
    set -l slots (_card_slots)
    test (count $slots) -eq 3; or _die "gpg --card-status failed for $serial"
    if test "$slots" != "- - -"
        _warn "This card already holds OpenPGP keys:"
        printf '      sig %s\n      enc %s\n      aut %s\n' $slots
        if _confirm "Reset the OpenPGP applet on $serial (erases its OpenPGP keys, PINs back to defaults)?" n
            _ask "Type the serial number $serial to confirm" ""
            test "$REPLY" = "$serial"; or _die "Serial did not match; nothing was changed."
            _release_card
            ykman --device $serial openpgp reset --force; or _die "Reset failed"
            _ok "OpenPGP applet reset (PIN 123456, Admin PIN 12345678)"
        else if not _confirm "Overwrite the existing slots when writing the subkeys?" n
            return 1
        end
    else
        _ok "All three slots are empty"
    end

    # PINs
    _header "PINs on $serial"
    _say "Factory defaults: PIN 123456, Admin PIN 12345678. Store the new ones in Bitwarden."
    if _confirm "Change the user PIN now?" y
        _release_card
        ykman --device $serial openpgp access change-pin; or _warn "PIN change failed"
    end
    if _confirm "Change the Admin PIN now?" y
        _release_card
        ykman --device $serial openpgp access change-admin-pin; or _warn "Admin PIN change failed"
    end

    # Touch policies (ykman 5 slot names: sig, dec, aut)
    _header "Touch policies on $serial"
    for pair in sig:on dec:on aut:cached
        set -l kv (string split : -- $pair)
        while true
            _ask "Touch policy for $kv[1] (off/on/fixed/cached/cached-fixed)" $kv[2]
            contains -- $REPLY off on fixed cached cached-fixed; and break
            _warn "Not a valid policy"
        end
        if string match -q -- '*fixed' $REPLY
            _confirm "'$REPLY' can't be changed later without deleting the key. Continue?" n; or continue
        end
        _release_card
        ykman --device $serial openpgp keys set-touch --force $kv[1] $REPLY
        and _ok "$kv[1] touch policy: $REPLY"
        or _warn "Could not set the touch policy for $kv[1]"
    end

    # Cardholder name
    if _confirm "Set the cardholder name?" y
        _ask Surname ""
        set -l sn $REPLY
        _ask "Given name" ""
        set -l gn $REPLY
        _release_card
        printf '%s\n' admin name $sn $gn quit | gpg --command-fd 0 --card-edit >/dev/null
        and _ok "Cardholder name set"
        or _warn "Setting the name failed; do it later with gpg --card-edit → admin → name"
    end

    _write_subkeys; or return 1
    _state_set card.$serial $label
    _ok "YubiKey $serial ($label) is ready"
end

function _write_subkeys
    _header "Writing the subkeys"
    _restore_keyring
    _release_card
    set -l slots (_card_slots)
    test (count $slots) -eq 3; or _die "gpg --card-status failed"

    set -l cmds
    set -l expect
    for line in (_subkeys)
        set -l f (string split ' ' -- $line)
        test "$f[4]" = r; and continue
        set -l slot
        switch $f[2]
            case '*s*'
                set slot 1
            case '*e*'
                set slot 2
            case '*a*'
                set slot 3
            case '*'
                continue
        end
        # select, move, answer slot (+ "replace?" when occupied), deselect
        set -a cmds "key $f[1]" keytocard $slot
        test "$slots[$slot]" != -; and set -a cmds y
        set -a cmds "key $f[1]"
        set -a expect $slot:$f[3]
    end
    for n in 1 2 3
        test (count (string match -- "$n:*" $expect)) -eq 1
        or _die "Expected exactly one usable subkey for card slot $n — check with: gpg --list-keys"
    end

    _say "gpg asks for the KEY passphrase, then this card's ADMIN PIN."
    printf '%s\n' $cmds save | gpg --command-fd 0 --edit-key $FPR

    if not _verify_card $expect
        _warn "The card doesn't hold the expected keys."
        _confirm "Retry interactively in gpg --edit-key?" y; or _die "Stopped. The backup is untouched."
        _restore_keyring
        _say "At the gpg> prompt type, one per line (key N toggles selection):"
        for c in $cmds save
            echo "      $c"
        end
        gpg --edit-key $FPR
        _verify_card $expect; or _die "The card still doesn't match. The backup is untouched."
    end
    _wipe_keyring
end

function step_ci
    _header "Export the CI signing subkey"
    _restore_keyring
    _ci_export
    _wipe_keyring
end

function step_daily
    _header "Daily keyring"
    _require_personal daily
    _wipe_keyring
    _need_backup
    _say "Reading the public key from the backup — enter the BACKUP passphrase."
    set -l pub (gpg --quiet --decrypt $YKGPG_BACKUP | tar -xOf - backup/public.asc | string collect)
    test -n "$pub"; or _die "Could not read the public key from the backup"
    set -g FPR (printf '%s\n' $pub | gpg --show-keys --with-colons 2>/dev/null | awk -F: '$1=="pub"{p=1;next} p && $1=="fpr"{print $10; exit}')
    printf '%s\n' $pub | gpg --quiet --import; or _die "Import failed"
    echo "$FPR:6:" | gpg --quiet --import-ownertrust
    _state_set fpr $FPR
    _ok "Imported $FPR into $_daily_home (ultimate trust)"

    if _confirm "Insert a configured YubiKey and create the card stubs now?" y
        _learn_card; or return 1
    end
    gpg --list-secret-keys $FPR 2>/dev/null
    or _warn "No secret stubs yet — insert a card and run: gpg --card-status"
    true
end

function _load_fpr
    if not set -q FPR; or test -z "$FPR"
        set -g FPR (_state_get fpr)
    end
    test -n "$FPR"; or _die "No key recorded yet — run: ykgpg daily (or the walkthrough)"
    gpg --list-keys $FPR >/dev/null 2>&1; or _die "$FPR is not in your daily keyring — run: ykgpg daily"
end

function step_test
    _header "Test each card"
    _require_personal test
    _wipe_keyring
    _load_fpr
    while true
        _learn_card; or return 1
        set -l t (mktemp)
        echo "ykgpg test "(date) >$t
        _say "Signing — enter the user PIN and touch the key when it blinks."
        if gpg --quiet --yes --detach-sign --local-user $FPR --output $t.sig $t
            and gpg --quiet --verify $t.sig $t 2>/dev/null
            _ok "Signing works on $CARD_SERIAL"
        else
            _warn "Signing failed on $CARD_SERIAL"
        end
        _say "Encryption round-trip — touch the key again."
        set -l out (echo ykgpg-roundtrip | gpg --quiet --trust-model always --encrypt --recipient $FPR | gpg --quiet --decrypt 2>/dev/null)
        if test "$out" = ykgpg-roundtrip
            _ok "Encryption works on $CARD_SERIAL"
        else
            _warn "Encryption round-trip failed on $CARD_SERIAL"
        end
        rm -f $t $t.sig
        _confirm "Test another card? (swap it in first)" y; or break
    end
    _say "Full release path, from the provider repo: set -gx GPG_FINGERPRINT $FPR; mise run release-dry"
end

function step_ssh
    _header "SSH via the [A] subkey"
    _require_personal ssh
    _wipe_keyring
    _load_fpr

    set -l conf $_daily_home/gpg-agent.conf
    if grep -qx enable-ssh-support $conf 2>/dev/null
        _ok "enable-ssh-support is already set"
    else
        _confirm "Add 'enable-ssh-support' to $conf?" y; or return 1
        echo enable-ssh-support >>$conf
        gpgconf --kill gpg-agent
        _ok "SSH support enabled in gpg-agent"
    end

    set -l snippet $HOME/.config/fish/conf.d/gnupg-ssh.fish
    if not test -f $snippet; or _confirm "$snippet exists. Overwrite it?" n
        if _confirm "Write $snippet so new fish sessions use gpg-agent for SSH?" y
            mkdir -p (dirname $snippet)
            printf '%s\n' \
                '# Written by ykgpg: use gpg-agent (YubiKey [A] subkey) as the SSH agent' \
                'if status is-interactive' \
                '    set -gx GPG_TTY (tty)' \
                '    set -e SSH_AGENT_PID' \
                '    set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)' \
                '    gpgconf --launch gpg-agent' \
                '    gpg-connect-agent updatestartuptty /bye >/dev/null' \
                end >$snippet
            _ok "Wrote $snippet (open a new terminal to pick it up)"
        end
    end

    set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
    gpgconf --launch gpg-agent
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
    _learn_card
    if ssh-add -L 2>/dev/null | string match -q '*cardno:*'
        _ok "gpg-agent offers the card's SSH key"
    else
        _warn "ssh-add -L doesn't show a cardno: key yet"
    end

    set -l pubf $HOME/.ssh/id_yubikey.pub
    if not test -f $pubf; or _confirm "$pubf exists. Overwrite it?" n
        mkdir -p $HOME/.ssh
        chmod 700 $HOME/.ssh
        gpg --export-ssh-key $FPR >$pubf; and _ok "SSH public key written to $pubf"
    end
    test -f $pubf; and cat $pubf
    _say "Add it to GitHub (Settings → SSH and GPG keys) and to servers' authorized_keys."
    if set -q XDG_CURRENT_DESKTOP; and string match -qi '*gnome*' -- $XDG_CURRENT_DESKTOP
        _warn "GNOME: make sure gnome-keyring's SSH agent isn't overriding SSH_AUTH_SOCK"
    end
end

function step_renew
    _header "Renew subkey expiry"
    _restore_keyring
    set -l fpr $FPR
    set -l before (_expiry_epoch)
    test -n "$before"; and _say "Earliest subkey expiry now: "(_fmt_date $before)
    _ask "New validity, counted from today" $YKGPG_EXPIRE
    set -l period $REPLY
    _say "Extending all subkeys — enter the KEY passphrase."
    gpg --quiet --quick-set-expire $FPR $period '*'; or _die "Extending the subkeys failed"
    set -l after (_expiry_epoch)
    _ok "Subkeys now expire "(_fmt_date $after)

    _write_backup
    set -l pub (gpg --armor --export $FPR | string collect)
    if _confirm "Re-export the CI signing subkey now? (the CI copy still has the old expiry)" y
        _ci_export
    else
        gpg --armor --export (_subkey_fpr s)"!" >$YKGPG_REGISTRY_KEY
        _ok "Registry public key refreshed: $YKGPG_REGISTRY_KEY"
    end
    _wipe_keyring

    if test $PROFILE = personal
        printf '%s\n' $pub | gpg --quiet --import; and _ok "Daily keyring updated"
    end
    _state_set expires $after
    _verify_backup $fpr
    step_offline
    _header "Still to do"
    echo "  • Upload $YKGPG_REGISTRY_KEY to both registries (same fingerprint, new expiry)"
    echo "  • Import the new public key on any other machine that uses it"
    echo "  • Shred the old backup(s): shred -u $YKGPG_BACKUP.*.old (and old offline copies)"
    echo "  • Reminder for next renewal: "(_fmt_date (math --scale=0 "$after - 60 * 86400"))
    test (count (_state_cards)) -gt 0; and echo "  • The YubiKeys don't need rewriting."
end

function step_edit
    _header "Edit the key from the backup"
    _restore_keyring
    set -l fpr $FPR
    _say "You are in gpg --edit-key on the throwaway keyring — adduid, deluid, primary, expire, passwd, …; 'save' before quitting."
    _warn "New or changed subkeys are NOT written to the YubiKeys (rerun 'card' for that); adduid/deluid need nothing on the cards."
    gpg --edit-key $fpr
    if not _confirm "Save the changes into a new backup?" y
        _wipe_keyring
        _say "Changes discarded — the backup is untouched."
        return 0
    end
    _write_backup
    set -l uid (gpg --with-colons --list-keys $fpr 2>/dev/null | awk -F: '$1=="uid"{print $10; exit}')
    test -z "$uid"; or _state_set uid $uid
    set -l e (_expiry_epoch)
    test -z "$e"; or _state_set expires $e
    set -l pub (gpg --armor --export $fpr | string collect)
    set -l sig (_subkey_fpr s)
    if test -n "$sig"
        gpg --armor --export "$sig!" >$YKGPG_REGISTRY_KEY
        _ok "Registry public key refreshed: $YKGPG_REGISTRY_KEY"
    end
    _wipe_keyring
    if test $PROFILE = personal
        printf '%s\n' $pub | gpg --quiet --import; and _ok "Daily keyring updated"
    end
    _verify_backup $fpr
    _say "The backup on this machine changed — copy it to offline drives: ykgpg -p $PROFILE offline"
    _say "Shred the old backup(s): shred -u $YKGPG_BACKUP.*.old (and old offline copies)"
end

# Every profile that exists: listed in the manifest or holding a state file.
function _all_profiles
    set -l profiles
    if test -f $YKGPG_STATE_DIR/personal.state; or contains -- personal (_profiles_list)
        set -a profiles personal
    end
    for p in (_profiles_list)
        contains -- $p $profiles; or set -a profiles $p
    end
    for f in $YKGPG_STATE_DIR/*.state
        test -f $f; or continue
        set -l p (string replace -r '\.state$' '' -- (basename $f))
        contains -- $p $profiles; or set -a profiles $p
    end
    for p in $profiles
        echo $p
    end
end

# One compact block per identity (shown when several exist).
function _status_summary --argument-names profile
    set -l fpr (_state_get fpr)
    if test -z "$fpr"
        echo "  $profile — no key recorded"
        return 0
    end
    _ok "$profile: "(_state_get uid)
    echo "      $fpr"
    set -l e (_state_get expires)
    if test -n "$e"
        set -l days (math --scale=0 "($e - "(date +%s)") / 86400")
        if test $days -lt 0
            _warn "Subkeys EXPIRED on "(_fmt_date $e)" — run: ykgpg -p $profile renew"
        else
            echo "      subkeys expire "(_fmt_date $e)" ($days days)"
        end
    end
    set -l bk yes
    test -f $YKGPG_BACKUP; or set bk no
    if test $bk = no
        set -l name (basename $YKGPG_BACKUP)
        for d in (_removable_dirs)
            test -f $d/$name; and set bk "yes (on a drive)"
        end
    end
    echo "      backup: $bk"
    echo "      cards: "(count (_state_cards))
end

# Full detail for the active profile (what `ykgpg status` always showed).
function _status_detail
    if _find_backup
        _ok "Backup: $YKGPG_BACKUP ("(date -r $YKGPG_BACKUP +%F)")"
        _is_local_path $YKGPG_BACKUP
        and _warn "The backup is on this machine — move it to offline drives: ykgpg offline"
    else
        _ok "Backup drive not plugged in (that's how it should be most of the time)"
    end

    set -l fpr (_state_get fpr)
    if test -z "$fpr"
        _warn "No key recorded yet for the $PROFILE profile"
        return 0
    end
    set -g FPR $fpr
    _ok "Key: $FPR"
    set -l uid (_state_get uid)
    if test -n "$uid"
        set -l name (string trim -- (string replace -r '<.*$' '' -- $uid))
        set -l email (string replace -r '^.*<' '' -- $uid | string replace -r '>.*$' '')
        echo "      uid: $uid"
        echo "      name: $name"
        echo "      email: $email"
    else
        _warn "No uid recorded for this key"
    end

    if gpg --list-keys $FPR >/dev/null 2>&1
        set -l e (_expiry_epoch)
        if test -n "$e"
            set -l days (math --scale=0 "($e - "(date +%s)") / 86400")
            if test $days -lt 0
                _warn "Subkeys EXPIRED on "(_fmt_date $e)" — run: ykgpg -p $PROFILE renew"
            else if test $days -lt 60
                _warn "Subkeys expire in $days days ("(_fmt_date $e)") — run: ykgpg -p $PROFILE renew"
            else
                _ok "Subkeys expire "(_fmt_date $e)" ($days days)"
            end
        end
    else if test $PROFILE = personal
        _warn "Key is not in your daily keyring — run: ykgpg daily"
    else
        _ok "Public key not in the daily keyring (normal for a release key)"
    end

    set -l cards (_state_cards)
    if test (count $cards) -gt 0
        for c in $cards
            set -l p (string split -m 1 = -- $c)
            _ok "Configured YubiKey $p[1] ($p[2])"
        end
    else if test $PROFILE = personal
        _warn "No YubiKeys configured yet"
    end

    if test $PROFILE != personal
        return 0
    end
    set -l present (ykman list --serials 2>/dev/null)
    if test (count $present) -eq 1; and gpg --list-keys $FPR >/dev/null 2>&1
        set -l sshpub (gpg --export-ssh-key $FPR 2>/dev/null | string collect)
        if test -n "$sshpub"
            _ok "SSH public key (private half lives in the YubiKey's [AUT] slot):"
            echo "      "(string trim -- $sshpub)
        else
            _warn "No authentication-capable subkey found — cannot derive an SSH key"
        end
        _release_card
        set -l slots (_card_slots)
        if test (count $slots) -ne 3
            _warn "Could not read the slots of YubiKey $present"
            return 0
        end
        set -l caps sig enc aut
        set -l want (_subkey_fpr s) (_subkey_fpr e) (_subkey_fpr a)
        set -l bad 0
        for i in 1 2 3
            set -l w $want[$i]
            test -z "$w"; and set w none
            if test $slots[$i] = $w
                _ok "Inserted YubiKey $present — $caps[$i] $slots[$i]"
            else
                _warn "$caps[$i]: card holds $slots[$i], keyring expects $w"
                set bad 1
            end
        end
        if test $bad = 0
            _ok "YubiKey $present holds all three current subkeys"
        else
            _warn "YubiKey $present does not hold the current subkeys"
        end
    end
end

function step_status
    _header Status
    _wipe_keyring
    if set -q _profile_explicit; and test $_profile_explicit = 1
        _status_detail
        return 0
    end
    set -l profiles (_all_profiles)
    switch (count $profiles)
        case 0
            _warn "No keys recorded yet (run: ykgpg generate, or: ykgpg -p <name> generate for a release key)"
            return 0
        case 1
            _resolve_profile $profiles[1]
            _status_detail
            return 0
    end
    _say "Identities ("(count $profiles)"):"
    for p in $profiles
        _resolve_profile $p
        _status_summary $p
    end
    _say "One identity in detail: ykgpg -p <name> status"
end

function step_walkthrough
    _require_personal walkthrough
    set_color --bold
    echo "ykgpg $YKGPG_VERSION — YubiKey OpenPGP setup ($YKGPG_ALGO, subkeys expire in $YKGPG_EXPIRE)"
    set_color normal
    echo "Profile: $PROFILE"
    echo "Backup file: $YKGPG_BACKUP"
    echo "Private keys are only handled in a throwaway tmpfs keyring that is wiped after each step."

    step_prep
    if _find_backup
        _ok "Backup found — skipping key generation (run 'ykgpg generate' to force a new key)"
    else
        _confirm "Generate the key now?" y; or return 0
        step_generate
    end

    while true
        set -l n (count (_state_cards))
        _say "YubiKeys set up so far: $n"
        set -l def n
        test $n -lt 3; and set def y
        _confirm "Set up a YubiKey now?" $def; or break
        step_card
    end

    _confirm "Export the CI signing subkey now?" y; and step_ci
    _confirm "Set up your daily keyring now?" y; and step_daily
    _confirm "Test each card now?" y; and step_test
    _confirm "Use the YubiKey for SSH?" n; and step_ssh
    step_status
end

function _usage
    echo "ykgpg $YKGPG_VERSION — guided YubiKey OpenPGP setup (see GPG-SIGNING-KEY.md)

Usage: ykgpg [-p <profile>] [command]

Profiles (key identities):
  Each profile is a separate OpenPGP key with its own primary key, subkeys,
  state file, encrypted backup and registry public key. Default: personal
  (your S/E/A-subkeys-on-YubiKeys key). Any other name is a software-only
  release key: certify-only primary + sign-only subkey, private half only
  inside its own encrypted backup, exported to CI like the personal CI subkey.
      ykgpg -p <name> generate    create the release key and its backup
      ykgpg -p <name> ci          export its signing subkey for CI
      ykgpg -p <name> renew       extend expiry, refresh its backup
      ykgpg -p <name> offline     copy its backup to drives (verified)
      ykgpg -p <name> status      that key in detail
      ykgpg status                overview of every identity
  card, test, ssh, daily and walkthrough apply to the personal key only.

Commands:
  walkthrough   Run every step in order, asking before each one (default)
  prep          Check tools, pcscd and pinentry
  generate      Create the key and the encrypted backup (once per profile)
  card          Prepare one YubiKey (PINs, touch, name) and write the subkeys
  ci            Export the signing subkey for CI, write the registry public key
  daily         Import the public key into your daily keyring, learn a card
  test          Sign and encrypt with each card
  ssh           Use the [A] subkey for SSH through gpg-agent
  renew         Extend subkey expiry; refresh backup, CI key and registry key
  edit          Load the backup into the throwaway keyring and run gpg --edit-key
                (adduid, deluid, …), then save a new backup
  offline       Copy the backup to removable drives (verified), remove the local copy
  status        All identities in brief; with -p, one identity in detail
  help          This text

Active profile: $PROFILE
  state file       $_state_file
  backup file      $YKGPG_BACKUP
  registry pubkey  $YKGPG_REGISTRY_KEY

Environment:
  YKGPG_PROFILE        default profile when -p is not passed
  YKGPG_BACKUP         encrypted backup (fallback for every profile)
                        ($YKGPG_BACKUP)
                        (if missing, the same file name is looked up on drives
                        mounted under /run/media/$USER and /media/$USER)
  YKGPG_ALGO           key algorithm       ($YKGPG_ALGO)
  YKGPG_EXPIRE         subkey validity     ($YKGPG_EXPIRE)
  YKGPG_REGISTRY_KEY   registry pubkey (fallback for every profile)
                        ($YKGPG_REGISTRY_KEY)
  YKGPG_STATE_DIR      non-secret state    ($YKGPG_STATE_DIR)
  YKGPG_PINENTRY       pinentry-program for the throwaway keyrings (optional)
  Per-profile overrides: any of the variables above with _<NAME> appended
  (profile uppercased, dashes to underscores), e.g.
  YKGPG_EXPIRE_FORWARDEMAIL=1y or YKGPG_BACKUP_FORWARDEMAIL=/run/media/$USER/KEYS1/forwardemail.tar.gpg"
end

function main
    if test -t 0
        set -gx GPG_TTY (tty)
    end
    argparse 'h/help' 'p/profile=' -- $argv
    or _die "Usage: ykgpg [-p <profile>] <command> — see: ykgpg help"
    if set -q _flag_help
        _usage
        return 0
    end
    set -l profile $YKGPG_PROFILE_DEFAULT
    set -g _profile_explicit 0
    if set -q _flag_p
        set profile $_flag_p
        set -g _profile_explicit 1
    else if test -n "$YKGPG_PROFILE"
        set profile $YKGPG_PROFILE
        set -g _profile_explicit 1
    end
    _profile_is_valid $profile
    or _die "Invalid profile name '$profile' — lowercase letters, digits, dashes and underscores only"
    _migrate_legacy_state
    _resolve_profile $profile

    set -l cmd walkthrough
    set -q argv[1]; and set cmd $argv[1]
    switch $cmd
        case walkthrough
            step_walkthrough
        case prep
            step_prep
        case generate
            step_generate
        case card
            step_card
        case ci
            step_ci
        case daily
            step_daily
        case test
            step_test
        case ssh
            step_ssh
        case registry
            _usage >&2
            _die "The registry step was removed — upload $YKGPG_REGISTRY_KEY to the Terraform/OpenTofu registries manually"
        case renew
            step_renew
        case edit
            step_edit
        case offline
            step_offline
        case status
            step_status
        case help -h --help
            _usage
        case '*'
            _usage >&2
            _die "Unknown command: $cmd"
    end
end

# Entry point. fish autoloads this file when the command `ykgpg` is typed,
# which only defines the functions below — nothing may run at top level, or
# the command stops existing after the first invocation. The dispatcher runs
# in a child fish so `exit` in _die aborts the step without closing the
# interactive shell.
function ykgpg --description "guided YubiKey OpenPGP setup"
    set -l self (status filename)
    fish --no-config -c 'source $argv[1]; and main $argv[2..]' -- $self $argv
    return $status
end
