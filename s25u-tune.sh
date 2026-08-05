#!/usr/bin/env bash
#
# s25u-tune.sh - idempotent tuning for Samsung Galaxy S25 Ultra (SM-S938B)
# Verified on: One UI 8.5 (ro.build.version.oneui=80500), Android 16, SDK 36
#
# Re-run after every OTA: updates restore some packages and reset animation
# scales. The script is safe to run any number of times.
#
# Usage:
#   ./s25u-tune.sh snapshot        # take a baseline snapshot (DO THIS FIRST)
#   ./s25u-tune.sh all             # apply everything
#   ./s25u-tune.sh debloat display # apply selected phases only
#   DRY=1 ./s25u-tune.sh all       # show what would happen, change nothing
#   ./s25u-tune.sh verify          # inspect current state only
#   ./s25u-tune.sh revert          # roll back settings (packages: see restore)
#   ./s25u-tune.sh restore         # reinstall all packages from the baseline
#
# Phases: snapshot debloat print doze display gmh misc verify
#
set -uo pipefail
# NOTE: -e is deliberately NOT enabled. `pm uninstall` on an already-removed
# package returns a non-zero exit code, so with `set -e` the script would die
# on the very first re-run - i.e. it would lose idempotency.

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

# Where state snapshots are stored. Required for rollback.
STATE_DIR="${STATE_DIR:-$HOME/.local/share/s25u-tune}"

# Animation scale. Do NOT use exactly 0: some apps rely on animator callbacks
# to drive UI state transitions, and at 0 those callbacks never fire (button
# looks pressed but state never changes). 0.35 avoids that entirely.
ANIM_SCALE="${ANIM_SCALE:-0.35}"

# Doze control. Two mechanisms do the same job; stacking them is harmful:
#   manual - via device_idle_constants (this script)
#   gmh    - via Galaxy Max Hz quick-doze (script clears device_idle_constants)
#   off    - do not touch Doze at all
DOZE_MODE="${DOZE_MODE:-manual}"

# Galaxy Max Hz package - granted the permissions it needs for refresh-rate control.
GMH_PKG="com.tribalfs.gmh"

# ─────────────────────────────────────────────────────────────────────────────
# PACKAGES TO REMOVE
# ─────────────────────────────────────────────────────────────────────────────
# Removal uses `pm uninstall --user 0`: the /system partition is untouched, so
# OTA is not blocked and a major One UI upgrade usually restores everything.
#
# The -k flag (keep data/cache) is deliberately NOT used: it frees no space,
# and a later install-existing hands the app a stale database - the classic
# cause of "I restored it and now it crashes".
#
# WARN - packages I would keep under observation: they break non-obvious things.
# +XDA - added from the reference list in XDA thread 4376755.
#
# --- About the reference list (important caveats) -------------------------
# Source: ADB AppControl preset, 2026-05-17, device SM-S931B.
#
# 1) SM-S931B is the BASE Galaxy S25, not the Ultra (SM-S938B). Its inventory
#    therefore lacks some Ultra-specific packages, and vice versa. 12 packages
#    from this list are absent from it entirely (uwbtest, coldwalletservice,
#    dck.timesync, visualars, kidshome, autodoodle, honeyplayplus, WizzAir,
#    some SMT variants) - not an error, just a different model/region/revision.
#
# 2) The author used `pm disable-user`, NOT `pm uninstall`. The file header
#    reads "Disabled applications". Disabling is instantly reversible and
#    leaves data intact, which let him be more aggressive than is justified
#    for uninstall. Copying his list 1:1 into removal is a bad idea.
#
# 3) What the list corroborates: of the 25 packages flagged WARN here on
#    reasoning alone, the author left almost all ENABLED - esimclient, sharelive,
#    scpm, sdm.config, nfwlocationprivacy, nsflp2, hearingadjust, allshare,
#    servicemodeapp, RilServiceModeApp, parser, vepreload, vebgm, modem.settings,
#    mocca, oda.service, bcservice, mydevice, hdmapp, mainline/virtualization.
#    Independent agreement is a strong signal. Treat those WARN marks seriously.

PACKAGES=(
    android.autoinstalls.config.samsung
    com.android.apps.tag                          # +XDA: NFC tag viewer; does not affect NFC payments
    com.android.bookmarkprovider                  # +XDA
    com.android.calllogbackup
    com.android.dreams.basic                      # +XDA: screensaver
    com.android.dreams.phototable                 # +XDA: screensaver
    com.android.egg
    com.android.hotwordenrollment.okgoogle
    com.android.hotwordenrollment.xgoogle
    com.android.microdroid.empty_payload          # WARN mainline/APEX, returns via Play system update
    com.android.providers.partnerbookmarks
    com.android.role.notes.enabled
    # com.android.stk                             # +XDA WARN SIM Toolkit: some carriers use it for
    # com.android.stk2                            #   menus/top-up. Rarely needed in the UK - your call
    com.android.theme.font.notoserifsource
    com.android.traceur                           # WARN System Tracing / Perfetto - may be useful
    com.android.virtualization.terminal           # WARN mainline
    com.android.virtualmachine.res                # WARN mainline
    com.android.wallpaper.livepicker              # +XDA: live wallpaper picker
    com.facebook.appmanager
    com.facebook.services
    com.facebook.system
    com.google.android.adservices.api             # WARN mainline, its update may start failing
    com.google.android.apps.accessibility.voiceaccess
    com.google.android.apps.aiwallpapers
    com.google.android.apps.restore
    com.google.android.as                         # WARN Android System Intelligence (XDA disables too):
                                                  #   Live Caption, smart clipboard, screenshot OCR,
                                                  #   Now Playing, Gboard smart reply
    com.google.android.federatedcompute
    com.google.android.feedback
    com.google.android.glasses.core               # +XDA
    com.google.android.gms.supervision
    com.google.android.ondevicepersonalization.services
    com.google.android.onetimeinitializer
    com.google.android.printservice.recommendation # +XDA: printer suggestions (printspooler stays)
    # com.google.android.projection.gearhead      # +XDA WARN Android Auto - the 2022 Leaf has it
    # com.google.android.tts                      # +XDA WARN Google TTS: speech, Accessibility, nav
    com.google.ar.core
    com.google.audio.hearing.visualization.accessibility.scribe
    com.google.mainline.adservices                # WARN mainline
    com.knox.vpn.proxyhandler
    com.microsoft.appmanager
    com.microsoft.skydrive
    com.monotype.android.font.foundation
    com.monotype.android.font.samsungone
    com.mygalaxy.service
    com.qti.qcc
    com.qti.snapdragon.qdcm_ff
    com.samsung.aasaservice
    # com.samsung.accessory.budsunitemgr          # +XDA WARN Galaxy Buds manager
    com.samsung.android.accessibility.talkback
    com.samsung.android.aircommandmanager         # WARN Air Command S Pen
    com.samsung.android.allshare.service.mediashare  # WARN Smart View / DLNA to TV
    com.samsung.android.app.camera.sticker.facearavatar.preload
    #     com.samsung.android.app.clipboardedge         # +XDA: clipboard panel in Edge panels
    # com.samsung.android.app.dressroom            # breaks lock screen settings
    com.samsung.android.app.earphonetypec         # WARN Samsung USB-C earbuds (plain UAC DACs unaffected)
    com.samsung.android.app.moments               # +XDA
    com.samsung.android.app.omcagent              # WARN CSC/OMC config - common cause of missing OTAs
    com.samsung.android.app.parentalcare
    com.samsung.android.app.sharelive             # WARN this is all of Quick Share, not just Link Sharing
    #     com.samsung.android.app.taskedge              # +XDA: task panel in Edge panels
    com.samsung.android.app.telephonyui.esimclient  # WARN! eSIM CLIENT. XDA left this enabled
    com.samsung.android.app.watchmanagerstub
    com.samsung.android.aremoji
    com.samsung.android.aremojieditor
    com.samsung.android.authfw                    # WARN Samsung FIDO/auth. XDA disables it too
    com.samsung.android.bbc.bbcagent
    com.samsung.android.beaconmanager
    com.samsung.android.bixby.agent
    com.samsung.android.bixbyvision.framework
    com.samsung.android.bixby.wakeup
    com.samsung.android.cameraxservice
    com.samsung.android.carkey
    com.samsung.android.coldwalletservice
    com.samsung.android.da.daagent
    com.samsung.android.dbsc
    com.samsung.android.dck.timesync
    com.samsung.android.dkey
    com.samsung.android.dsms
    com.samsung.android.dynamiclock                # +XDA
    com.samsung.android.easysetup
    com.samsung.android.fast
    com.samsung.android.forest
    com.samsung.android.game.gametools
    com.samsung.android.game.honeyplayplus
    com.samsung.android.hdmapp                    # WARN purpose unclear, keep under observation
    com.samsung.android.inputshare
    com.samsung.android.ipsgeofence
    com.samsung.android.kidsinstaller
    com.samsung.android.knox.analytics.uploader
    # com.samsung.android.knox.attestation          # required for Secure Folder
    # com.samsung.android.knox.containercore        # required for Secure Folder
    # com.samsung.android.knox.kpecore              # required for Secure Folder
    # com.samsung.knox.securefolder                 # required for Secure Folder
    com.samsung.android.knox.pushmanager
    com.samsung.android.knox.zt.framework
    com.samsung.android.liveeffectservice          # +XDA
    com.samsung.android.mapsagent
    com.samsung.android.mcfds
    com.samsung.android.mcfserver                  # +XDA: pairs with mcfds, already removed above
    com.samsung.android.mdecservice
    com.samsung.android.mdm
    com.samsung.android.mdx                       # WARN Samsung DeX / Link to Windows. XDA disables too
    com.samsung.android.mdx.kit
    com.samsung.android.mocca                     # WARN purpose unclear, keep under observation
    com.samsung.android.mydevice                  # WARN purpose unclear, keep under observation
    com.samsung.android.net.wifi.wifiguider        # +XDA
    com.samsung.android.networkdiagnostic
    com.samsung.android.rubin.app
    com.samsung.android.samsungpass
    com.samsung.android.samsungpassautofill
    com.samsung.android.scloud
    com.samsung.android.scpm                      # WARN! update configs; XDA kept it. May break OTA
    com.samsung.android.sdm.config                # WARN same as above
    com.samsung.android.server.wifi.mobilewips
    com.samsung.android.service.peoplestripe
    com.samsung.android.service.stplatform        # WARN purpose unclear, keep under observation
    com.samsung.android.shortcutbackupservice
    com.samsung.android.smartsuggestions
    com.samsung.android.smartswitchassistant
    com.samsung.android.stickercenter
    com.samsung.android.svcagent
    com.samsung.android.visionintelligence
    com.samsung.android.visualars
    com.samsung.faceservice
    com.samsung.gpuwatchapp
    com.samsung.oda.service                       # WARN purpose unclear, keep under observation
    com.samsung.safetyinformation
    com.samsung.sait.sohservice
    com.samsung.SMT.lang_ar_ae_m00                 # +XDA
    com.samsung.SMT.lang_de_de_f00
    com.samsung.SMT.lang_de_de_g01
    com.samsung.SMT.lang_de_de_l01
    com.samsung.SMT.lang_es_es_f00
    com.samsung.SMT.lang_es_es_g01
    com.samsung.SMT.lang_es_es_l01
    com.samsung.SMT.lang_es_mx_f00
    com.samsung.SMT.lang_es_us_f00                 # +XDA
    com.samsung.SMT.lang_id_id_f00                 # +XDA
    com.samsung.SMT.lang_fr_fr_f00
    com.samsung.SMT.lang_hi_in_f00
    com.samsung.SMT.lang_it_it_f00
    com.samsung.SMT.lang_pl_pl_f00                 # +XDA
    com.samsung.SMT.lang_pt_br_f00                 # +XDA
    # com.samsung.SMT.lang_en_gb_f00               # +XDA WARN your own locale - TTS goes silent
    # com.samsung.SMT.lang_en_us_l03               # +XDA WARN same family
    # com.samsung.SMT.lang_ru_ru_f00               # +XDA WARN you read Russian
    com.samsung.SMT.lang_th_th_f00
    com.samsung.SMT.lang_vi_vn_f00
    com.samsung.storyservice
    com.sec.android.app.billing
    com.sec.android.app.bluetoothagent
    com.sec.android.app.chromecustomizations
    com.sec.android.app.factorykeystring
    com.sec.android.app.hwmoduletest
    com.sec.android.app.kidshome
    com.sec.android.app.magnifier
    com.sec.android.app.parser                    # WARN network diagnostics (*#0011#)
    com.sec.android.app.servicemodeapp            # WARN same, plus band lock
    com.sec.android.app.setupwizardlegalprovider
    com.sec.android.app.uwbtest
    com.sec.android.app.vepreload                 # WARN Gallery video editor (video trimming)
    com.sec.android.app.ve.vebgm                  # WARN same as above
    com.sec.android.app.wlantest
    com.sec.android.autodoodle.service
    com.sec.android.CcInfo
    com.sec.android.diagmonagent
    com.sec.android.easyMover
    com.sec.android.easyMover.Agent
    com.sec.android.easyonehand
    com.sec.android.iaft
    com.sec.android.mimage.avatarstickers
    com.sec.android.RilServiceModeApp             # WARN network diagnostics
    com.sec.android.smartfpsadjuster              # adaptive FPS throttling - competes with GMH
    com.sec.android.widgetapp.easymodecontactswidget
    com.sec.app.RilErrorNotifier
    com.sec.bcservice                             # WARN purpose unclear, keep under observation
    com.sec.enterprise.knox.cloudmdm.smdms
    com.sec.epdgtestapp
    com.sec.facatfunction
    com.sec.factory.camera
    com.sec.hearingadjust                         # WARN! Adapt Sound in audio settings; XDA kept it
    com.sec.imslogger
    com.sec.location.nfwlocationprivacy           # WARN network-initiated location, emergency path
    com.sec.location.nsflp2                       # WARN same as above
    com.sec.modem.settings                        # WARN purpose unclear, keep under observation
    com.sec.spp.push                              # WARN Samsung Push: SmartThings, 2FA, Members
    com.sem.factoryapp
    com.swiftkey.swiftkeyconfigurator
    com.touchtype.swiftkey                        # WARN if this is the active IME you lose text input
    com.wizzair.WizzAirApp
    com.wsomacp
)

# --- What XDA disables that is deliberately NOT included here ---------------
# Not because the author is wrong - he disables, we uninstall, so the cost of a
# mistake is higher. If you decide to take any of these, add them ONE AT A TIME.
#
#   com.sec.android.app.safetyassurance   Emergency SOS / emergency message
#   com.sec.android.emergencylauncher     sending and emergency mode. The one
#                                         category where the answer is simply
#                                         "do not touch".
#
#   com.google.android.setupwizard        after a factory reset the phone may
#                                         fail to complete initial setup
#   com.google.android.googlequicksearchbox \
#   com.google.android.aicore                > kill Gemini and Circle to Search
#   com.google.android.apps.bard           /
#
#   com.samsung.android.honeyboard        Samsung Keyboard. Reports of bootloop
#                                         when used with DeX - though for
#                                         uninstall, not disable
#   com.samsung.knox.securefolder         Secure Folder packages are commented
#                                         out above, i.e. the feature is in use
#   com.samsung.android.spayfw            Samsung Pay/Wallet framework
#   com.samsung.android.sm.devicesecurity security scanning
#   com.google.android.apps.photos        \
#   com.google.android.youtube             > personal preference, not tuning
#   com.google.android.apps.tachyon (Meet)/

# ─────────────────────────────────────────────────────────────────────────────
# PACKAGES TO RESTORE
# ─────────────────────────────────────────────────────────────────────────────
# printspooler is the entire print framework. Without it you lose not only
# printing but also "Save as PDF" in Chrome, Gmail and every app that uses the
# system print dialog. This is exactly what broke here.
# The XDA reference (SM-S931B, 2026-05-17) confirms the diagnosis: the author
# left printspooler and bips ENABLED and disabled only
# printservice.recommendation. So printspooler is the culprit behind broken PDF
# export, while printer suggestions are safe to remove (moved to PACKAGES).
RESTORE_PACKAGES=(
    com.android.printspooler   # print framework + "Save as PDF". PDF EXPORT DIES WITHOUT IT
    com.android.bips           # built-in network printing (Mopria/IPP)
)

# ─────────────────────────────────────────────────────────────────────────────
# INFRASTRUCTURE
# ─────────────────────────────────────────────────────────────────────────────

DRY="${DRY:-0}"
declare -a FAILED=()
declare -a SKIPPED=()

c_red=$'\033[31m'; c_grn=$'\033[32m'; c_ylw=$'\033[33m'
c_blu=$'\033[34m'; c_dim=$'\033[2m';  c_rst=$'\033[0m'

log()  { printf '%s\n' "$*"; }
ok()   { printf '  %sok%s   %s\n' "$c_grn" "$c_rst" "$*"; }
warn() { printf '  %sskip%s %s\n' "$c_ylw" "$c_rst" "$*"; }
err()  { printf '  %sFAIL%s %s\n' "$c_red" "$c_rst" "$*"; }
head1(){ printf '\n%s══ %s %s\n' "$c_blu" "$*" "$c_rst"; }
dry()  { printf '  %s[dry] %s%s\n' "$c_dim" "$*" "$c_rst"; }

# Wrapper around adb shell: strips the \r that Android appends to every line.
# Without this, any string comparison breaks unpredictably.
sh_() { adb shell "$@" 2>&1 | tr -d '\r'; }

# Returns 0 if <pkg> appears in `pm list packages <flags...>`.
#
# Why this exists instead of a plain pipeline: under `set -o pipefail` the
# obvious idiom
#     sh_ pm list packages --user 0 | grep -qFx "package:$pkg"
# is BROKEN. `grep -q` exits 0 on its FIRST match and closes the pipe; the
# upstream `tr` inside sh_ then dies of SIGPIPE (exit 141), and pipefail makes
# the whole pipeline report 141 - so a successful match reads as a failure.
#
# It bites hardest on packages early in the alphabet (com.android.bips,
# com.android.printspooler), because grep exits while adb is still streaming
# ~530 lines. Packages late in the list happen to work, which makes the bug
# look selective and firmware-specific. It is neither.
#
# Fix: buffer the listing into a variable first (command substitution reads to
# EOF, so nothing can SIGPIPE), then match from a here-string - no pipe at all.
#
# Always pass --user 0. Plain `pm list packages` walks every user and on
# devices with Secure Folder (user 150) fails with
#   SecurityException: Shell does not have permission to access user 150
# which truncates the output unpredictably.
pkg_present() {
    local pkg=$1; shift
    local out
    out=$(sh_ pm list packages "$@")
    grep -qFx "package:$pkg" <<<"$out"
}

# ─────────────────────────────────────────────────────────────────────────────
# PREFLIGHT CHECKS
# ─────────────────────────────────────────────────────────────────────────────
preflight() {
    head1 "Preflight checks"

    command -v adb >/dev/null || { err "adb not found in PATH"; exit 1; }

    # Start the server up front, otherwise the first adb call prints the
    # "daemon started successfully" banner to stdout and corrupts parsing.
    adb start-server >/dev/null 2>&1

    # get-state returns `device` only for a single connected target.
    # Without this check, a sleeping adb makes the whole loop run against an
    # empty package list and report "everything already removed" - the most
    # treacherous failure mode, because it looks like success.
    local state
    state=$(adb get-state 2>/dev/null | tr -d '\r')
    if [ "$state" != "device" ]; then
        err "device unavailable (get-state='$state'). Check the cable and USB-debugging authorisation."
        exit 1
    fi

    local model fw sdk
    model=$(sh_ getprop ro.product.model)
    fw=$(sh_ getprop ro.build.version.release)
    sdk=$(sh_ getprop ro.build.version.sdk)
    ok "device: $model, Android $fw (SDK $sdk)"

    # Active keyboard. SwiftKey is on the removal list; if it is the current
    # system IME, removing it leaves no way to enter text at all - including
    # the PIN on some screens.
    local ime
    ime=$(sh_ settings get secure default_input_method)
    log "  active IME: $ime"
    for pkg in "${PACKAGES[@]}"; do
        case "$ime" in
            "$pkg"/*)
                err "the active keyboard ($pkg) is on the removal list. Switch IME in Settings, then retry."
                exit 1
                ;;
        esac
    done

    # Active launcher - same logic, but less fatal.
    local launcher
    launcher=$(sh_ cmd package resolve-activity -c android.intent.category.HOME \
                   -a android.intent.action.MAIN 2>/dev/null | awk -F= '/packageName/{print $2}' | head -1)
    [ -n "$launcher" ] && log "  active launcher: $launcher"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE: SNAPSHOT - baseline state capture
# ─────────────────────────────────────────────────────────────────────────────
# Without this, rollback becomes guesswork. The snapshot contains:
#   packages.txt   - all packages, including ones already removed for user 0 (-u)
#   settings-*.txt - full dumps of all three namespaces
#   props.txt      - build.prop, which holds the correct DPI values
phase_snapshot() {
    head1 "Taking baseline snapshot"
    mkdir -p "$STATE_DIR"
    local stamp; stamp=$(date +%Y%m%d-%H%M%S)
    local dir="$STATE_DIR/$stamp"

    if [ "$DRY" = 1 ]; then dry "snapshot -> $dir"; return; fi
    mkdir -p "$dir"

    # -u includes packages uninstalled for the user. That is the list needed to
    # later compute what was removed and restore exactly that set.
    sh_ pm list packages -u --user 0 | sed 's/^package://' | sort > "$dir/packages.txt"
    ok "packages recorded: $(wc -l < "$dir/packages.txt")"

    for ns in global secure system; do
        sh_ settings list "$ns" | sort > "$dir/settings-$ns.txt"
    done
    ok "settings: global/secure/system"

    sh_ getprop > "$dir/props.txt"
    # On the S25U the DPI properties disagree, and `wm density reset` restores
    # the WRONG one. Record the correct values so there is something to return to:
    #   vendor.display.lcd_density = 560  <- correct DPI for QHD+
    #   ro.sf.lcd_density          = 450  <- applies to FHD+
    #   ro.sf.init.lcd_density     = 600  <- fallback, and what `reset` gives you
    grep -E 'lcd_density' "$dir/props.txt" | sed 's/^/    /'
    sh_ wm density  > "$dir/wm-density.txt"
    sh_ wm size    >> "$dir/wm-density.txt"
    ok "$(tr '\n' ' ' < "$dir/wm-density.txt")"

    ln -sfn "$dir" "$STATE_DIR/latest"
    ok "snapshot: $dir  (latest symlink updated)"
}

# ─────────────────────────────────────────────────────────────────────────────
# SETTINGS HELPERS
# ─────────────────────────────────────────────────────────────────────────────
#
# The key fact that keeps forum command lists alive for years: `settings put`
# on a NON-EXISTENT key silently creates a row, reports success, and does
# nothing. Nobody verifies, so One UI 4-era commands get copied indefinitely.
#
# Hence two distinct helpers:

# sset_safe - writes ONLY if the key already exists.
# For settings that mirror an existing UI toggle: if the key is absent, the
# feature does not exist in this firmware and writing is pointless.
sset_safe() {
    local ns=$1 key=$2 val=$3 desc=${4:-}
    local cur
    cur=$(sh_ settings get "$ns" "$key")
    if [ "$cur" = "null" ]; then
        SKIPPED+=("$ns/$key")
        warn "$ns/$key absent in this firmware ${desc:+- $desc}"
        return
    fi
    if [ "$cur" = "$val" ]; then
        ok "$ns/$key already = $val"
        return
    fi
    if [ "$DRY" = 1 ]; then dry "$ns/$key: $cur -> $val"; return; fi
    sh_ settings put "$ns" "$key" "$val" >/dev/null
    local new; new=$(sh_ settings get "$ns" "$key")
    if [ "$new" = "$val" ]; then ok "$ns/$key: $cur -> $val ${desc:+($desc)}"
    else err "$ns/$key: wrote $val, read back $new"; FAILED+=("$ns/$key"); fi
}

# sset_force - writes regardless of whether the key currently exists.
# For settings absent by default that the system still reads when present
# (device_idle_constants, peak_refresh_rate on some firmwares).
# Use only for keys whose effect has been confirmed.
sset_force() {
    local ns=$1 key=$2 val=$3 desc=${4:-}
    local cur; cur=$(sh_ settings get "$ns" "$key")
    if [ "$cur" = "$val" ]; then ok "$ns/$key already = $val"; return; fi
    if [ "$DRY" = 1 ]; then dry "$ns/$key: $cur -> $val (force)"; return; fi
    sh_ settings put "$ns" "$key" "$val" >/dev/null
    ok "$ns/$key: $cur -> $val ${desc:+($desc)}"
}

sdel() {
    local ns=$1 key=$2
    if [ "$DRY" = 1 ]; then dry "delete $ns/$key"; return; fi
    sh_ settings delete "$ns" "$key" >/dev/null
    ok "$ns/$key reset to default"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE: DEBLOAT
# ─────────────────────────────────────────────────────────────────────────────
phase_debloat() {
    head1 "Removing packages (${#PACKAGES[@]} listed)"

    # One pm call instead of 180: saves roughly 2 minutes of adb round-trips.
    local installed
    installed=$(sh_ pm list packages --user 0 | sed 's/^package://')

    local removed=0 absent=0
    for pkg in "${PACKAGES[@]}"; do
        # grep -qFx: fixed string, whole-line match. Without -x,
        # `com.samsung.android.mdx` would also match `com.samsung.android.mdx.kit`.
        if ! printf '%s\n' "$installed" | grep -qFx "$pkg"; then
            absent=$((absent+1))
            continue
        fi

        if [ "$DRY" = 1 ]; then dry "uninstall $pkg"; removed=$((removed+1)); continue; fi

        # pm uninstall prints its result to stdout and OFTEN returns exit
        # code 0 even on Failure. The output text is the only reliable signal.
        local out; out=$(sh_ pm uninstall --user 0 "$pkg")
        case "$out" in
            Success*) ok "$pkg"; removed=$((removed+1)) ;;
            *)        err "$pkg -> $out"; FAILED+=("$pkg") ;;
        esac
    done

    log ""
    log "  removed now: $removed, already absent: $absent"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE: PRINT - restore printing and PDF export
# ─────────────────────────────────────────────────────────────────────────────
phase_print() {
    head1 "Restoring print framework"

    local installed
    installed=$(sh_ pm list packages --user 0 | sed 's/^package://')

    for pkg in "${RESTORE_PACKAGES[@]}"; do
        if printf '%s\n' "$installed" | grep -qFx "$pkg"; then
            ok "$pkg already present"
            continue
        fi
        if [ "$DRY" = 1 ]; then dry "install-existing $pkg"; continue; fi

        # install-existing reinstalls the APK from the system partition for
        # user 0. Idempotent on an already-installed package.
        local out; out=$(sh_ cmd package install-existing "$pkg")

        # DO NOT pattern-match the output. On failure this command prints
        # "Package <pkg> is not installed for user 0", which contains the
        # substring "installed" - a glob like *installed* matches it and
        # reports a failure as success. Verify the postcondition instead.
        if pkg_present "$pkg" --user 0; then
            ok "$pkg"
        else
            err "$pkg -> $out"
            FAILED+=("$pkg")
            # Distinguish "removed for this user" from "not on the device at
            # all": only the former can be brought back by install-existing.
            if pkg_present "$pkg" -u --user 0; then
                log "  ${c_dim}present in the -u inventory, so it exists in /system${c_rst}"
            else
                log "  ${c_ylw}absent from the -u inventory - this package does not${c_rst}"
                log "  ${c_ylw}exist on this device, so it cannot be the cause${c_rst}"
            fi
        fi
    done
    log "  ${c_dim}check: Chrome -> Print -> \"Save as PDF\" should reappear${c_rst}"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE: DOZE
# ─────────────────────────────────────────────────────────────────────────────
phase_doze() {
    head1 "Doze / device_idle"

    if [ "$DOZE_MODE" = "off" ]; then
        warn "DOZE_MODE=off - leaving Doze alone"
        return
    fi

    if [ "$DOZE_MODE" = "gmh" ]; then
        # GMH quick-doze does the same job with its own mechanism. Two
        # independent Doze forcings stack and produce "notifications arrive
        # 20 minutes late". Keep one - the one that has a UI.
        log "  DOZE_MODE=gmh - resetting device_idle_constants to the firmware default"
        sdel global device_idle_constants
        return
    fi

    # --- WHY MERGE INSTEAD OF WRITING A STRING ------------------------------
    # On One UI 8.5 the device_idle_constants key is ALREADY populated with a
    # full explicit set (28 parameters, including the entire light_* branch).
    # Writing a short string there makes every omitted parameter fall back to
    # the hardcoded AOSP default rather than Samsung's value - i.e. it blindly
    # wipes the light-Doze tuning (light_idle_to=3600000 plus eight others).
    #
    # Just as important: Samsung already tuned deep idle MORE aggressively than
    # AOSP - idle_to=43200000 (12 h) versus the 60 min default, and
    # max_idle_to=86400000 (24 h) versus 6 h. Shortening those sleep windows
    # makes things worse: the shorter they are, the more often the phone wakes
    # up for maintenance.
    #
    # So change ONLY the Doze ENTRY parameters and nothing else.
    local -a OVERRIDES=(
        inactive_to=10000          # 30000 -> 10000: wait 10 s after screen off
        sensing_to=0               #  5000 -> 0: skip the sensing stage entirely
        locating_to=0              #  5000 -> 0: do not wait for a location fix
        idle_after_inactive_to=0   # 60000 -> 0: no pause between INACTIVE and IDLE
    )
    #
    # DELIBERATELY LEFT OUT: motion_inactive_to=0
    #
    # Samsung's default is 3600000 (1 h), which effectively gates deep Doze
    # behind the device being still. Setting it to 0 removes that gate, so the
    # phone drops into deep Doze while riding in your pocket - and that is the
    # single change most likely to delay notifications.
    #
    # Consequence of keeping Samsung's value: deep Doze engages overnight and
    # when the phone sits on a desk, but not while it is with you. That is the
    # conservative trade and the reason it stays.
    #
    # Honest note on what the remaining four buy you: they only shorten the
    # ENTRY path, by roughly 90 s after screen-off. The actual battery win from
    # Doze comes from the sleep windows, and Samsung already sets those to 12 h
    # (idle_to) and 24 h (max_idle_to). Ninety seconds against that is noise.
    # If you want no Doze tinkering at all, use DOZE_MODE=off - you lose very
    # little. Re-enable the aggressive behaviour by adding this line above:
    #     motion_inactive_to=0
    # Deliberately NOT touched: idle_to, max_idle_to, idle_factor,
    # idle_pending_to, max_idle_pending_to, min_time_to_alarm, the whole light_*
    # branch, wait_for_unlock. An earlier version of this script overwrote them,
    # which was a bug.
    #
    # The key location_accuracy_to DOES NOT EXIST (the real name is
    # location_accuracy, no suffix). Forum commands include it and it is
    # silently ignored.

    local cur; cur=$(sh_ settings get global device_idle_constants)
    [ "$cur" = "null" ] && cur=""

    # Parse the current string into pairs, preserving the original key order so
    # that a before/after diff stays readable.
    local -a order=(); local -A kv=()
    local pair key
    local oldifs="$IFS"; IFS=','
    for pair in $cur; do
        [ -n "$pair" ] || continue
        key=${pair%%=*}
        [ -n "${kv[$key]+x}" ] || order+=("$key")
        kv[$key]=${pair#*=}
    done
    IFS="$oldifs"

    log "  parameters read: ${#order[@]}"

    local changed=0
    for pair in "${OVERRIDES[@]}"; do
        key=${pair%%=*}
        local val=${pair#*=}
        if [ "${kv[$key]-}" = "$val" ]; then
            ok "$key already = $val"
            continue
        fi
        log "  $key: ${kv[$key]-<unset>} -> $val"
        [ -n "${kv[$key]+x}" ] || order+=("$key")
        kv[$key]=$val
        changed=$((changed+1))
    done

    if [ "$changed" -eq 0 ]; then
        ok "all overrides already in place"
        return
    fi

    # Reassemble
    local out=""
    for key in "${order[@]}"; do
        out+="${out:+,}$key=${kv[$key]}"
    done

    if [ "$DRY" = 1 ]; then dry "device_idle_constants (${#order[@]} parameters, $changed changed)"; return; fi

    sh_ settings put global device_idle_constants "$out" >/dev/null

    # CRITICAL: on a syntax error KeyValueListParser silently falls back to
    # defaults for the ENTIRE set. `settings get` still returns our string in
    # that case, so verify against what the service actually accepted.
    # Canary parameter: one we DO set, whose applied value is unambiguous in the
    # dump. sensing_to renders as a bare "0" when set, or "+5s0ms" at Samsung's
    # default, so the two cases cannot be confused. motion_inactive_to is no
    # longer suitable as a canary because we no longer change it.
    local applied
    applied=$(sh_ dumpsys deviceidle | grep -oE '\bsensing_to=[^ ]+' | head -1)
    if [ "$applied" = "sensing_to=0" ]; then
        ok "accepted by the service ($changed changes)"
    else
        err "service reports '${applied:-<not found>}' instead of sensing_to=0 - parser rejected the string"
        FAILED+=("device_idle_constants")
    fi

    log ""
    log "  ${c_dim}setAlarmClock (alarms, timers) is exempt from Doze - safe.${c_rst}"
    log "  ${c_dim}High-priority FCM (messengers, mail) bypasses Doze and still${c_rst}"
    log "  ${c_dim}arrives; normal-priority FCM and JobScheduler wait for a${c_rst}"
    log "  ${c_dim}maintenance window. motion_inactive_to is left at Samsung's${c_rst}"
    log "  ${c_dim}1 h, so deep Doze needs the device to be still.${c_rst}"
    log "  ${c_dim}Exempt an app: adb shell dumpsys deviceidle whitelist +<pkg>${c_rst}"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE: DISPLAY
# ─────────────────────────────────────────────────────────────────────────────
phase_display() {
    head1 "Display: refresh rate and animations"

    # --- REFRESH RATE: NOT CONTROLLABLE VIA ADB ON ONE UI 8.5 ---------------
    # Verified on SM-S938B / One UI 8.5 (80500):
    #   system/peak_refresh_rate      -> null (key does not exist)
    #   system/min_refresh_rate       -> null (key does not exist)
    #   system/user_refresh_rate      -> null
    #   system/adaptive_refresh_rate  -> null
    #   secure/refresh_rate_mode      -> 1     <- the only one that exists
    #
    # refresh_rate_mode is the binary "Motion smoothness" toggle:
    #   0 = Standard (60 Hz), 1 = Adaptive (up to 120 Hz)
    # It is already 1, so adaptive mode is on and there is nothing to override.
    #
    # ACTUAL panel modes on SM-S938B (dumpsys display, measured 2026-08-04):
    #   10, 24, 30, 48, 60, 80, 120 Hz
    # Note: there is NO 96 Hz, but there IS 80. The widely-quoted list
    # "1/10/24/48/60/96/120" does not apply to this device, so the 96 Hz
    # sweet-spot idea is simply not available here. Selecting 80 is not
    # possible either - refresh_rate_mode is binary.
    #
    # An earlier version of this script wrote 2 here. That was DANGEROUS: the
    # key exists, so the null check would not have filtered it out, and this
    # firmware appears to have no value 2 - the display could have ended up in
    # an undefined state. The write has been removed.
    #
    # If fine-grained rate control is ever needed (96 Hz, separate rates for
    # screen-off/AOD), that requires a third-party app such as Galaxy Max Hz
    # layered on top of the system mechanism. It is not installed here.
    log "  refresh_rate_mode = $(sh_ settings get secure refresh_rate_mode) ${c_dim}(0=60Hz, 1=adaptive)${c_rst}"
    log "  ${c_dim}peak/min_refresh_rate do not exist in this firmware - skipping${c_rst}"

    # Animations, in the global namespace. One UI resets these when power
    # saving is enabled and after updates, and Accessibility -> Reduce
    # animations overrides them. Hence re-running this script after every OTA.
    sset_force global window_animation_scale     "$ANIM_SCALE" "windows"
    sset_force global transition_animation_scale "$ANIM_SCALE" "transitions"
    sset_force global animator_duration_scale    "$ANIM_SCALE" "animators"

    # -- DPI: deliberately commented out ---------------------------------
    # The correct value for QHD+ on the S25U is 560 (vendor.display.lcd_density).
    # BUT: the value depends on the current resolution, and `wm density reset`
    # restores 600 (ro.sf.init.lcd_density) rather than 560 - so the built-in
    # rollback lies. Uncomment deliberately, using the snapshot value:
    #
    #   sh_ wm density 560
    #
    # Change resolution with the BUILT-IN toggle in Settings, not `wm size`:
    # wm size does not fully reconfigure the display pipeline and breaks the
    # camera plus apps that hardcode assumptions about surface size.
    log "  ${c_dim}wm density left alone (see comment in script). Current:${c_rst}"
    # `wm density` returns two lines (Physical / Override) - flatten them,
    # otherwise the indented log output breaks apart.
    log "  ${c_dim}  $(sh_ wm density | tr '\n' ' ')${c_rst}"
}

# --- WHY THERE IS NO RAM PLUS PHASE HERE -------------------------------------
# Measurement on SM-S938B / One UI 8.5 showed the swap is ZRAM and RAM Plus is
# off, i.e. there is nothing to tune:
#   /sys/block/zram0/disksize        = 4294967296  (exactly 4 GiB)
#   /sys/block/zram0/comp_algorithm  = lzo [lzo-rle] lz4 zstd  (lzo-rle active)
#   dumpsys meminfo -> ZRAM: 743,204K physical used for 2,336,892K in swap
#   settings get global ram_expand_size = 0
#
# Compression ratio 3.14x and no writes to UFS. Disabling this is neither
# needed nor possible: ram_expand_size controls RAM Plus, not zram, and it is
# already 0.
#
# Switching comp_algorithm to zstd is also not worth it even with access: on a
# phone, page-fault latency dominates, and lzo-rle decompresses several times
# faster. zstd would give ~3.5-4x at the cost of noticeably more CPU per fault.
# Besides, comp_algorithm is only writable on an empty zram and needs root.
#
# If RAM Plus ever turns out to be ENABLED (SwapTotal notably larger than the
# zram0 disksize), a dedicated phase becomes worthwhile.

# ─────────────────────────────────────────────────────────────────────────────
# PHASE: GMH - permissions for Galaxy Max Hz
# ─────────────────────────────────────────────────────────────────────────────
phase_gmh() {
    head1 "Galaxy Max Hz permissions"

    if ! pkg_present "$GMH_PKG" --user 0; then
        warn "$GMH_PKG not installed - skipping phase"
        return
    fi

    if [ "$DRY" = 1 ]; then dry "granting the listed permissions to $GMH_PKG"; return; fi

    # WRITE_SECURE_SETTINGS is the main one: it allows changing secure settings,
    # including refresh rate. Be aware of the scope: this grants access to the
    # ENTIRE secure settings namespace, not just display-related keys.
    sh_ pm grant "$GMH_PKG" android.permission.WRITE_SECURE_SETTINGS >/dev/null && ok "WRITE_SECURE_SETTINGS"

    # DUMP reads system service state; quick-doze needs it so that GMH can see
    # the actual deviceidle state.
    sh_ pm grant "$GMH_PKG" android.permission.DUMP >/dev/null && ok "DUMP"

    # These two go through appops rather than pm grant: they are app-op modes,
    # not runtime permissions. `pm grant` simply errors out on them.
    sh_ appops set "$GMH_PKG" WRITE_SETTINGS allow   >/dev/null && ok "appop WRITE_SETTINGS"
    sh_ appops set "$GMH_PKG" GET_USAGE_STATS allow  >/dev/null && ok "appop GET_USAGE_STATS"

    log ""
    log "  ${c_dim}Useful in-app: Force lowest Hz on screen-off/AOD${c_rst}"
    log "  ${c_dim}and Auto sensors off (kills motion wakelocks in standby).${c_rst}"
    log "  ${c_dim}The power-saving CPU limit is hardcoded at 70% and cannot change.${c_rst}"
    log "  ${c_dim}Quick-doze is tied to power saving mode by default.${c_rst}"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE: MISC - background scanning
# ─────────────────────────────────────────────────────────────────────────────
# All via sset_safe: these keys mirror UI toggles, so an absent key means the
# feature does not exist in this firmware. Do not create junk rows.
phase_misc() {
    head1 "Background scanning"

    # BLE scanning with Bluetooth off is a constant source of wakeups.
    sset_safe global ble_scan_always_enabled 0 "BLE scan with BT off"

    # Nearby device scanning - Samsung-specific ambient scanning.
    sset_safe system nearby_scanning_enabled            0 "nearby device scanning"
    sset_safe system nearby_scanning_permission_allowed 0 "same, permission flag"

    # Wi-Fi scanning for location: DELIBERATELY LEFT ENABLED.
    # Turning it off stops apps from scanning Wi-Fi while Wi-Fi is switched off,
    # which is what location services use for a fast coarse fix. Accuracy drops
    # noticeably indoors and in the first seconds after opening a map app, while
    # the power saving is small. Bad trade. Uncomment only if you disagree:
    #
    #   sset_safe global wifi_scan_always_enabled 0 "Wi-Fi scan for location"

    log ""
    log "  ${c_dim}Skipped keys are NOT an error: it means this firmware has no${c_rst}"
    log "  ${c_dim}such setting, and the borrowed command is out of date.${c_rst}"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE: VERIFY
# ─────────────────────────────────────────────────────────────────────────────
# Check the ACTUAL state of each subsystem, not what we wrote. The difference
# matters: `settings get` returns our string even when the parser rejected it.
phase_verify() {
    head1 "Verifying actual state"

    log "${c_blu}-- Doze: values accepted by the system --${c_rst}"
    # This output is what the parser ACTUALLY accepted.
    # Defaults appearing here mean the string had a syntax error.
    sh_ dumpsys deviceidle | sed -n '/Settings:/,/^$/p' | sed 's/^/  /' | head -30

    log ""
    log "${c_blu}-- Doze: current state --${c_rst}"
    # `get deep` / `get light` are cleaner than grepping mState: light mode
    # lives in a separate state machine and grep conflates the two.
    log "  deep : $(sh_ dumpsys deviceidle get deep)"
    log "  light: $(sh_ dumpsys deviceidle get light)"
    log "  ${c_dim}test without waiting: dumpsys deviceidle force-idle, then unforce${c_rst}"

    log ""
    log "${c_blu}-- Doze whitelist --${c_rst}"
    # Often the main drain culprit: Samsung whitelists a fair number of
    # packages by default, and device_idle_constants does not apply to them.
    local wl; wl=$(sh_ dumpsys deviceidle whitelist | grep -c . || true)
    log "  whitelist entries: $wl  ${c_dim}(full list: dumpsys deviceidle whitelist)${c_rst}"
    # A large whitelist can dominate everything else: device_idle_constants
    # simply does not apply to exempt packages, no matter how aggressive.
    if [ "${wl:-0}" -gt 100 ] 2>/dev/null; then
        log "  ${c_ylw}NOTE${c_rst} whitelist is large - exempt packages ignore device_idle_constants"
        log "  ${c_dim}review non-system entries:${c_rst}"
        log "  ${c_dim}  adb shell dumpsys deviceidle whitelist | grep -v '^system'${c_rst}"
    fi

    log ""
    log "${c_blu}-- Memory --${c_rst}"
    # Informational: confirm this is still zram rather than RAM Plus.
    local ds; ds=$(sh_ cat /sys/block/zram0/disksize 2>/dev/null | grep -oE '^[0-9]+')
    local st; st=$(sh_ grep '^SwapTotal' /proc/meminfo | grep -oE '[0-9]+')
    if [ -n "$ds" ] && [ -n "$st" ]; then
        log "  zram0: $((ds/1024/1024)) MiB, SwapTotal: $((st/1024)) MiB"
        # If SwapTotal is substantially larger than zram, RAM Plus (a swap
        # file on UFS) is enabled on top, and that IS worth turning off.
        if [ "$((st/1024))" -gt "$((ds/1024/1024 + 256))" ]; then
            warn "SwapTotal exceeds zram - RAM Plus appears to be enabled"
        else
            ok "swap = zram, RAM Plus is off"
        fi
    else
        warn "could not read zram/meminfo"
    fi
    log "  ram_expand_size = $(sh_ settings get global ram_expand_size)"

    log "${c_blu}-- Display --${c_rst}"
    log "  refresh_rate_mode : $(sh_ settings get secure refresh_rate_mode)  ${c_dim}(0=60Hz, 1=adaptive)${c_rst}"
    log "  animations        : $(sh_ settings get global window_animation_scale) / $(sh_ settings get global transition_animation_scale) / $(sh_ settings get global animator_duration_scale)"
    log "  ${c_dim}modes the panel actually reports:${c_rst}"
    # Pulls the genuinely supported mode list out of the display service -
    # more reliable than trusting forum lists of "supported" rates.
    # grep -oE rather than awk: dumpsys also contains "Adding refreshRateToken"
    # lines which sort BEFORE fps= and get truncated by any head.
    sh_ dumpsys display | tr ',' '\n' | grep -oE 'fps=[0-9.]+' | cut -d= -f2 \
        | sort -un | sed 's/^/    /'
    log "  ${c_dim}visual check: developer options -> Show refresh rate${c_rst}"

    log ""
    log "${c_blu}-- GMH --${c_rst}"
    if pkg_present "$GMH_PKG" --user 0; then
        sh_ dumpsys package "$GMH_PKG" | grep -A15 -i 'runtime permissions' \
            | grep -Ei 'WRITE_SECURE_SETTINGS|DUMP' | sed 's/^/  /' || warn "permissions not found in the dump"
    else
        warn "not installed"
    fi

    log ""
    log "${c_blu}-- Printing --${c_rst}"
    for pkg in "${RESTORE_PACKAGES[@]}"; do
        if pkg_present "$pkg" --user 0; then
            ok "$pkg present"
        else
            case "$pkg" in
                com.android.printspooler) err "$pkg absent - printing AND Save-as-PDF are dead" ;;
                com.android.bips)         err "$pkg absent - no built-in network printing" ;;
                *)                        err "$pkg absent" ;;
            esac
        fi
    done

    log ""
    log "${c_blu}-- Uninstalled for user 0 --${c_rst}"
    if [ -e "$STATE_DIR/latest/packages.txt" ]; then
        local now total
        now=$(mktemp)
        sh_ pm list packages --user 0 | sed 's/^package://' | sort > "$now"
        # The snapshot is written with -u, so it holds the FULL inventory
        # including packages already uninstalled for the user. The current
        # listing has no -u, i.e. installed only. The delta is therefore
        # "everything ever uninstalled for user 0", not "removed since the
        # snapshot was taken" - an easy label to get wrong.
        # comm -13: lines only in file 2 = in the inventory, absent now.
        local gone; gone=$(comm -13 "$now" "$STATE_DIR/latest/packages.txt" | grep -c . || true)
        total=$(grep -c . < "$STATE_DIR/latest/packages.txt")
        log "  $gone of $total inventory packages are uninstalled for user 0"
        log "  ${c_dim}full list: comm -13 <(adb shell pm list packages --user 0 |${c_rst}"
        log "  ${c_dim}  tr -d '\\r' | sed 's/^package://' | sort) \\${c_rst}"
        log "  ${c_dim}  $STATE_DIR/latest/packages.txt${c_rst}"
        rm -f "$now"
    else
        warn "no snapshot - run './s25u-tune.sh snapshot'"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# ROLLBACK
# ─────────────────────────────────────────────────────────────────────────────
phase_revert() {
    head1 "Reverting settings (packages untouched)"

    # `settings delete` returns the key to the system default. Better than
    # writing a "default" value by hand: the default can differ across regions
    # and firmware versions.
    sdel global device_idle_constants
    # peak/min_refresh_rate do not exist on 8.5, refresh_rate_mode is left
    # alone (it is the user's "Motion smoothness" toggle), and ram_expand_size
    # is never written - so there is nothing to roll back.

    # Animations are the exception: delete sometimes leaves them at zero until
    # reboot, so write an explicit 1.
    sset_force global window_animation_scale     1 "default"
    sset_force global transition_animation_scale 1 "default"
    sset_force global animator_duration_scale    1 "default"

    log ""
    log "  ${c_dim}Resolution changes require a reboot.${c_rst}"
    log "  ${c_dim}Packages are restored separately: ./s25u-tune.sh restore${c_rst}"
}

phase_restore() {
    head1 "Restoring all packages from the baseline snapshot"

    local base="$STATE_DIR/latest/packages.txt"
    [ -e "$base" ] || { err "no snapshot at $base"; exit 1; }

    local now; now=$(mktemp)
    sh_ pm list packages --user 0 | sed 's/^package://' | sort > "$now"

    # The delta between snapshot and current state = what to restore.
    local -a to_restore=()
    while IFS= read -r pkg; do
        [ -n "$pkg" ] && to_restore+=("$pkg")
    done < <(comm -13 "$now" "$base")
    rm -f "$now"

    log "  to restore: ${#to_restore[@]}"
    for pkg in "${to_restore[@]}"; do
        if [ "$DRY" = 1 ]; then dry "install-existing $pkg"; continue; fi
        local out; out=$(sh_ cmd package install-existing "$pkg")
        # Same trap as in phase_print: the failure message contains the word
        # "installed", so verify the postcondition rather than the text.
        if pkg_present "$pkg" --user 0; then
            ok "$pkg"
        else
            err "$pkg -> $out"; FAILED+=("$pkg")
        fi
    done
    log ""
    log "  ${c_dim}Reboot after restoring.${c_rst}"
}

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
summary() {
    head1 "Summary"
    [ "$DRY" = 1 ] && log "  ${c_ylw}DRY-RUN: nothing was changed${c_rst}"

    if [ "${#SKIPPED[@]}" -gt 0 ]; then
        log "  ${c_ylw}absent keys: ${#SKIPPED[@]}${c_rst}  ${c_dim}(normal - stale commands)${c_rst}"
        printf '    %s\n' "${SKIPPED[@]}"
    fi

    if [ "${#FAILED[@]}" -gt 0 ]; then
        log "  ${c_red}errors: ${#FAILED[@]}${c_rst}"
        printf '    %s\n' "${FAILED[@]}"
        return 1
    fi
    log "  ${c_grn}no errors${c_rst}"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
usage() {
    sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

[ $# -eq 0 ] && usage

# revert/restore/snapshot are standalone operations, not mixed into `all`.
case "${1:-}" in
    revert)   preflight; phase_revert;   summary; exit $? ;;
    restore)  preflight; phase_restore;  summary; exit $? ;;
    snapshot) preflight; phase_snapshot; exit 0 ;;
esac

preflight

# A snapshot is taken automatically before any mutating run if none exists.
# Cheaper than discovering one day that there is nothing to roll back to.
if [ ! -e "$STATE_DIR/latest/packages.txt" ] && [ "$DRY" != 1 ]; then
    log ""
    warn "no baseline snapshot - taking one automatically"
    phase_snapshot
fi

PHASES=("$@")
[ "${1:-}" = all ] && PHASES=(debloat print doze display gmh misc verify)

for p in "${PHASES[@]}"; do
    case "$p" in
        debloat) phase_debloat ;;
        print)   phase_print   ;;
        doze)    phase_doze    ;;
        display) phase_display ;;
        gmh)     phase_gmh     ;;
        misc)    phase_misc    ;;
        verify)  phase_verify  ;;
        all)     ;;
        *) err "unknown phase: $p"; usage ;;
    esac
done

summary
