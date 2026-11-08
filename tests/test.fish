#!/usr/bin/env fish
# tests/test.fish — pure-logic acceptance tests for the ykgpg plugin.
#
# No hardware, no real GnuPG, no network: gpg is shadowed by a function that
# serves checked-in --with-colons fixtures (see tests/fixtures/).
#
# These tests target the REFACTORED plugin (function names `__ykgpg_*`,
# implemented in IMPLEMENTATION_PLAN.md Phases 1–6). Against the v1.0.0
# baseline the suite exits 1 immediately with a clear message — that is the
# acceptance-test contract: red until the refactor lands, green after.
#
# Run from the repo root:  fish tests/test.fish

set -l root (cd (dirname (status filename))/..; and pwd)
# Global, not local: __t increments it from inside its own scope.
set -g fails 0

# Sourcing in a non-interactive fish defines the full helper set, exactly as
# the child dispatcher does. YKGPG_CHILD prevents the script-mode `main` call.
set -gx YKGPG_CHILD 1
source $root/functions/ykgpg.fish
set -e YKGPG_CHILD

# Guard: against the unrefactored v1.0.0 baseline, unknown __ykgpg_* functions
# would make assertions abort silently and the suite would lie. Refuse instead.
if not functions -q __ykgpg_state_set
    echo "FATAL: the __ykgpg_* API does not exist — IMPLEMENTATION_PLAN.md"
    echo "Phases 1–2 have not been applied to functions/ykgpg.fish yet."
    exit 1
end

function __t --argument-names desc expected actual
    if test "$expected" = "$actual"
        echo "  ok    $desc"
    else
        set -g fails (math $fails + 1)
        echo "  FAIL  $desc"
        echo "        expected: [$expected]"
        echo "        actual:   [$actual]"
    end
end

echo "state helpers"
# ---------------------------------------------------------------------------

set -gx YKGPG_STATE_DIR (mktemp -d)
set -g YKGPG_STATE $YKGPG_STATE_DIR/state

__ykgpg_state_set fpr ABCDEF
__ykgpg_state_set uid "Test User <t@example.com>"
__ykgpg_state_set card.12345678 active
__ykgpg_state_set expires 1780000000

__t "state_get returns the last value" ABCDEF (__ykgpg_state_get fpr)
__t "state_get value with spaces" "Test User <t@example.com>" (__ykgpg_state_get uid)
__t "state_get missing key fails" 1 (begin; __ykgpg_state_get nope; echo $status; end)

__ykgpg_state_set fpr NEWFPR
__t "state_set replaces, not appends" 1 (count (string match -- "^fpr=*" <$YKGPG_STATE))
__t "state_set replace value" NEWFPR (__ykgpg_state_get fpr)

set -l cards (__ykgpg_state_cards)
__t "state_cards count" 1 (count $cards)
__t "state_cards entry" "12345678=active" $cards[1]

__ykgpg_state_clear_cards
__t "state_clear_cards removes only cards" NEWFPR (__ykgpg_state_get fpr)
__t "state_clear_cards emptied cards" 0 (count (__ykgpg_state_cards))

__t "state file is 0600" 600 (stat -c %a $YKGPG_STATE 2>/dev/null; or stat -f %Lp $YKGPG_STATE)

echo "subkey parsing (GnuPG 2.4 fixture)"
# ---------------------------------------------------------------------------
# Shadow gpg with a fixture-serving function. All helpers call plain `gpg`,
# never `command gpg`, so the shadow takes effect everywhere.

function gpg --inherit-variable root
    cat $root/tests/fixtures/list-keys-2.4.colons
end

set -g FPR AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
set -l subs (__ykgpg_subkeys)
__t "subkeys count" 3 (count $subs)
__t "subkeys line 1 (index caps fpr validity expiry)" \
    "1 s BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB - 1780000000" $subs[1]
__t "subkey_fpr s" BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB (__ykgpg_subkey_fpr s)
__t "subkey_fpr e" CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC (__ykgpg_subkey_fpr e)
__t "subkey_fpr a" DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD (__ykgpg_subkey_fpr a)
__t primary_fpr AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA (__ykgpg_primary_fpr)
__t "expiry_epoch is the minimum subkey expiry" 1780000000 (__ykgpg_expiry_epoch)

functions -e gpg

echo "expired subkeys are ignored"
# ---------------------------------------------------------------------------
# A fixture whose [s] subkey is expired (validity "e"): it must not be
# selected for cards, cards-only or expiry.

set -g FPR AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
function gpg --inherit-variable root
    cat $root/tests/fixtures/list-keys-expired-sub.colons
end
__t "expired [s] subkey not chosen by subkey_fpr" \
    "" (__ykgpg_subkey_fpr s | string collect)
__t "expiry ignores expired subkey" "" (__ykgpg_expiry_epoch | string collect)
functions -e gpg

echo "platform helpers"
# ---------------------------------------------------------------------------
# __ykgpg_sha256 and __ykgpg_mtime land in Phase 4; guard so the suite can
# run (and report) while earlier phases are still in progress.

if functions -q __ykgpg_sha256
    set -l f (mktemp)
    echo -n ykgpg >$f
    __t "sha256 across implementations" \
        (sha256sum $f 2>/dev/null; or shasum -a 256 $f; or openssl dgst -sha256 -r $f | string split -f1 ' ') \
        (__ykgpg_sha256 $f)
    rm -f $f
else
    echo "  skip  __ykgpg_sha256 (not implemented yet — Phase 4)"
end

if functions -q __ykgpg_mtime
    set -l f (mktemp)
    __t "mtime is a plausible epoch" 0 (test (math (date +%s) - (__ykgpg_mtime $f)) -lt 5; and echo 0; or echo 1)
    rm -f $f
else
    echo "  skip  __ykgpg_mtime (not implemented yet — Phase 4)"
end

# ---------------------------------------------------------------------------
echo
if test $fails -eq 0
    echo "All tests passed."
    exit 0
end
echo "$fails test(s) failed."
exit 1
