#!/usr/bin/env zsh
# Enable debug tracing only if DEBUG environment variable is set
[[ -n "$DEBUG" ]] && set -x
# ===================================================================
#  Zsh Disk Guard Plugin with Pac‑Man‑Style Progress Bar
#  Intelligent disk space monitoring for write operations
#
#  Author: Tom from Berlin
#  License: MIT
#  Repository: https://github.com/TomfromBerlin/diskguard
# ──────────────────────────────────────────────────────────────────
# "You can lead a horse to water, but you can't make it read warnings."
#                                               — Ancient IT Wisdom
# ──────────────────────────────────────────────────────────────────
# ===================================================================
# ──────────────────────────────────────────────────────────────────
#  Version Check
# ──────────────────────────────────────────────────────────────────
# Load version comparison function
if ! autoload -Uz is-at-least 2>/dev/null; then
    print -P "%F{red}Error: Cannot load is-at-least function%f" >&2
    return 1
fi
#
# Require Zsh 5.0+
autoload -Uz is-at-least
if ! is-at-least 5.0; then
    gdbus call --session \
    --dest=org.freedesktop.Notifications \
    --object-path=/org/freedesktop/Notifications \
    --method=org.freedesktop.Notifications.Notify \
    "" 0 "" "diskguard Plugin Message" "Unsupported Zsh version $ZSH_VERSION. Expecting Zsh 5.0+! The plugin diskguard was not loaded." \
    '[]' '{"urgency": <1>}' 30000
    return 1
fi

# Allow reload in debug/test mode
if [[ -n "$_diskguard_loaded" && -z "$DEBUG" ]]; then
    _diskguard_debug "Plugin already loaded, skipping (set DEBUG=1 to force reload)"
    return
fi
typeset -g _diskguard_loaded=1
typeset -g DISKGUARD_PLUGIN_DIR="${0:A:h}"
typeset -g DISKGUARD_FUNC_DIR="${0:A:h}/functions"
#
# Load UI helpers & default values
[[ -f "${DISKGUARD_FUNC_DIR}/diskguard_missing_tools" ]] && source "${DISKGUARD_FUNC_DIR}/diskguard_missing_tools" && diskguard_missing_tools
[[ -f "${DISKGUARD_FUNC_DIR}/diskguard_ui" ]] && source "${DISKGUARD_FUNC_DIR}/diskguard_ui"

# ────────────────────────────────────────────────────────────────
# Lazy-load (loading scripts on demand)
# ────────────────────────────────────────────────────────────────
_diskguard_cp() {
    source "${DISKGUARD_FUNC_DIR}/_diskguard_cp"
    _diskguard_cp "$@"
}
_diskguard_deinit_term() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_term_control"
    _diskguard_deinit_term "$@"
}
_diskguard_init_term() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_term_control"
    _diskguard_init_term "$@"
}
_diskguard_mv() {
    source "${DISKGUARD_FUNC_DIR}/_diskguard_mv"
    _diskguard_mv "$@"
}
_diskguard_progress_bar() {
    source "${DISKGUARD_FUNC_DIR}/_diskguard_progress_bar"
    _diskguard_progress_bar "$@"
}
_diskguard_rsync() {
    source "${DISKGUARD_FUNC_DIR}/_diskguard_rsync"
    _diskguard_rsync "$@"
}
diskguard_cleanup() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_cleanup"
    diskguard_cleanup "$@"
}
diskguard_color() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_color"
    diskguard_color "$@"
}
colortest() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_color"
    colortest "$@"
}
diskguard_defaults() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_defaults"
    diskguard_defaults "$@"
}
diskguard_func_debug() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_func_debug"
    diskguard_func_debug "$@"
}
diskguard_status() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_status"
    diskguard_status "$@"
}
diskguard_validate_input_perc() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_validate_input_perc"
    diskguard_validate_input_perc "$@"
}
diskguard_write_config() {
    source "${DISKGUARD_FUNC_DIR}/diskguard_write_config"
    diskguard_write_config "$@"
}

# ──────────────────────────────────────────────────────────────────
# Redraw prompt when terminal size changes
# ──────────────────────────────────────────────────────────────────
TRAPWINCH() {
  zle && zle -R
}
# ──────────────────────────────────────────────────────────────────
#  Configuration settings
# ──────────────────────────────────────────────────────────────────
if [[ -f "${DISKGUARD_PLUGIN_DIR}/diskguard.conf" ]] ; then
    source "${DISKGUARD_PLUGIN_DIR}/diskguard.conf"
    printf '%s' "Configuration loaded from config file."
else
# Disk usage threshold (percentage)
: ${DISKGUARD_THRESHOLD:=80}

# Size threshold for deep checking (bytes)
: ${DISKGUARD_SCAN_THRESHOLD:=$((100 * 1000 * 1000))}  # 100 MB

# Enable debug output
: ${DISKGUARD_DEBUG:=0}

# Enable/disable the plugin
: ${DISKGUARD_ENABLED:=1}

# Commands to wrap (space-separated)
: ${DISKGUARD_COMMANDS:="cp mv rsync"}
fi
# ──────────────────────────────────────────────────────────────────
#  Helper Functions
# ──────────────────────────────────────────────────────────────────

# Debug output function
_diskguard_debug() {
    local LC_ALL=C
    (( DISKGUARD_DEBUG )) && print -P "%F{cyan}DEBUG:%f $*" >&2
}

# Check if a string is a valid number
_diskguard_is_number() {
    local LC_ALL=C
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

# ──────────────────────────────────────────────────────────────────
# Portable df wrapper for usage, available, size, or mountpoint
# Arguments:
#   $1 = metric: "pcent", "avail", "size", "mountpoint"
#   $2 = path
# Returns:
#   Numeric value (bytes or percentage) or mountpoint path
# ──────────────────────────────────────────────────────────────────
diskguard_df() {
    local LC_ALL=C
    local metric=$1
    local target=$2
    local is_gnu=0
    local result

    # Detect GNU df
    if command df --help 2>&1 | grep -q -- '--output'; then
        is_gnu=1
    fi

    if (( is_gnu )); then
        case $metric in
            pcent)
                result=$(command df --output=pcent "$target" 2>/dev/null | tail -n1 | tr -d ' %')
                ;;
            avail)
                result=$(command df --output=avail "$target" 2>/dev/null | tail -n1 | tr -d ".,")
                result=$((result * 1024))
                ;;
            size)
                result=$(command df --output=size "$target" 2>/dev/null | tail -n1 | tr -d ".,")
                result=$((result * 1024))
                ;;
            mountpoint)
                result=$(command df --output=target "$target" 2>/dev/null | tail -n1 | tr -d ".,")
                ;;
            *)
                printf '%s %s\n' "Unknown metric:" "$metric" >&2
                return 1
                ;;
        esac
    else
        # BSD/macOS fallback
        local line
        line=$(command df -k "$target" 2>/dev/null | tail -1)
        case $metric in
            pcent)
                result=$(echo "$line" | awk '{print int($5)}')
                ;;
            avail)
                result=$(echo "$line" | awk '{print $4 * 1024}')
                ;;
            size)
                result=$(echo "$line" | awk '{print $2 * 1024}')
                ;;
            mountpoint)
                result=$(echo "$line" | awk '{print $6}')
                ;;
            *)
                printf '%s %s\n' "Unknown metric:" "$metric" >&2
                return 1
                ;;
        esac
    fi

    printf '%s\n' "$result"
    return 0
}

# ──────────────────────────────────────────────────────────────────
# Quick size calculation (files only, no directories)
# Returns 1 if directories are found (needs deep check)
# ──────────────────────────────────────────────────────────────────
_diskguard_quick_size() {
    local LC_ALL=C
    local total=0
    local item size

    for item in "$@"; do
        [[ "$item" == -* ]] && continue
        [[ ! -e "$item" ]] && continue

        if [[ -f "$item" ]]; then
            size=$(command stat -c%s "$item" 2>/dev/null || command stat -f%z "$item" 2>/dev/null || echo 0)
            [[ "$size" =~ ^[0-9]+$ ]] || size=0
            (( total += size ))
        elif [[ -d "$item" ]]; then
            return 1  # Needs deep check
        fi
    done

    printf '%s\n' "$total"
    return 0
}

# ──────────────────────────────────────────────────────────────────
# Deep size calculation (includes directories)
# ──────────────────────────────────────────────────────────────────
_diskguard_deep_size() {
    local LC_ALL=C
    local total=0
    local item size

    for item in "$@"; do
        [[ "$item" == -* ]] && continue
        [[ ! -e "$item" ]] && continue

        if [[ -f "$item" ]]; then
            size=$(command stat -c%s "$item" 2>/dev/null || command stat -f%z "$item" 2>/dev/null || echo 0)
        elif [[ -d "$item" ]]; then
            size=$(command du -sb "$item" 2>/dev/null | command cut -f1 || echo 0)
        else
            size=0
        fi
        [[ "$size" =~ ^[0-9]+$ ]] || size=0
        (( total += size ))
    done

    printf '%s\n' "$total"
}

# ──────────────────────────────────────────────────────────────────
# Format size in human-readable format (Bytes, KiB, MiB, GiB)
# ──────────────────────────────────────────────────────────────────
_diskguard_format_size() {
_diskguard_debug "reached function _diskguard_format_size" /dev/tty

    local LC_ALL=C
    local bytes=$1
    local gib rem_gib mb rem_mb mib rem_mib kib

    [[ "$bytes" =~ ^[0-9]+$ ]] || { printf '%s\n' "n/a"; return 1; }

    (( kib = bytes / 1024 ))
    (( rem_kib = (bytes % 1024) / 1024 ))
    (( mb = bytes / 1000000 ))
    (( rem_mb = (bytes % 1000000) * 100 / 1000000 ))
    (( mib = bytes / 1048576 ))
    (( rem_mib = (bytes % 1048576) * 100 / 1048576 ))
    (( gib = bytes / 1073741824 ))
    (( rem_gib = (bytes % 1073741824) * 100 / 1073741824 ))

    if (( gib >= 1 )); then
        printf "%d.%02d GiB → %d.%02d MiB\n" "$gib" "$rem_gib" "$mib" "$rem_mib"
        return 0
    elif (( mb > 500 && gib < 1 )); then
        printf "%d.%02d MiB → %d.%02d GiB\n" "$mib" "$rem_mib" "$gib" "$rem_gib"
        return 0
    elif (( mb >= 1 && mb <= 500 )); then
        printf "%d.%02d MB → %d.%02d MiB\n" "$mb" "$rem_mb" "$mib" "$rem_mib"
        return 0
    elif (( kib >= 1 && mib < 1  )); then
        printf "%d.%02d KiB → %d.%03d MiB\n" "$kib" "$rem_kib" "${mib}" "${rem_mib}"
        return 0
    elif (( kib > 0 && kib < 1  )); then
    # below 1 KiB → seriously? Do you use 5¼-inch floppy disks, or magnet tapes?
        printf "%d Bytes → %d.%02d KB\n" "$bytes" "$kib" "$rem_kib"
    return 0
    fi

    printf '%s %s\n' "${bytes}" "Bytes"
}

# ──────────────────────────────────────────────────────────────────
# Verify disk space availability before write operations
# Arguments:
#   $1 = target path
#   $@ = source files/directories
# Returns:
#   0 if sufficient space, 1 otherwise
# ──────────────────────────────────────────────────────────────────
_diskguard_verify() {
    unset CREATE_GLOBAL_WARN create_global_warn
    local LC_ALL=C
    local target="$1"
    shift
    local sources
    sources=("$@")

    _diskguard_debug "Checking target: $target"
    [[ -z "$target" ]] && return 0

    target=${target:a}
    _diskguard_debug "Resolved target: $target"

    if [[ ! -d "$target" ]]; then
        _diskguard_debug "Not a directory, extracting path..."
        if [[ $target == */* ]]; then
            target=${target%/*}
            [[ -z "$target" ]] && target=/
        else
            target=.
        fi
        _diskguard_debug "Extracted to: $target"
    fi

    # Check if files exist and calculate the size accordingly
    local already_exists_size existing_size
    already_exists_size=0
    for source in "${sources[@]}"; do
        # local target_file #← this produces unwanted output
        if [[ -d "$target" ]]; then
            target_file="${target}/${source:t}"
        else
            target_file="$target"
        fi

        if [[ -f "$target_file" ]]; then
          #  local existing_size
            existing_size=$(command stat -c%s "$target_file" 2>/dev/null || \
                            command stat -f%z "$target_file" 2>/dev/null || echo 0)
            (( already_exists_size += existing_size ))
        fi
    done

    _diskguard_debug "Getting mountpoint for: $target"
    local mountpoint
    mountpoint=$(diskguard_df mountpoint "$target")
    _diskguard_debug "Mountpoint: '$mountpoint'"

    [[ -z "$mountpoint" ]] && { _diskguard_debug "Mountpoint empty, aborting"; return 0; }

    _diskguard_debug "Checking usage of: $mountpoint"
    local usage_perc
    usage_perc=$(diskguard_df pcent "$mountpoint")
    _diskguard_debug "Raw usage: '$usage_perc'"

    [[ "$usage_perc" =~ ^[0-9]+$ ]] || { _diskguard_debug "Usage not numeric, aborting"; return 0; }

    _diskguard_debug "Parsed usage: ${usage_perc}% (threshold: ${DISKGUARD_THRESHOLD}%)"

    local estimated_size needs_deep_check=0 total_size available total_space after_write usage_after

    estimated_size=$(_diskguard_quick_size "${sources[@]}")
    [[ $? -ne 0 ]] && { needs_deep_check=1; _diskguard_debug "Directory detected → deep check required"; }

    if (( needs_deep_check == 0 )); then
        _diskguard_debug "Quick check: $(_diskguard_format_size $estimated_size)"
        if (( estimated_size < DISKGUARD_SCAN_THRESHOLD )); then
            if (( usage_perc >= DISKGUARD_THRESHOLD )); then
                printf '\n%s\n' "⚠️  ${DISKGUARD_COLOR_RED}Warning${DISKGUARD_COLOR_NC}: Partition ${DISKGUARD_COLOR_CYAN}$mountpoint${DISKGUARD_COLOR_NC} is ${DISKGUARD_COLOR_YELLOW_BOLD}${usage_perc}%${DISKGUARD_COLOR_NC} full!" >&2
                if [[ -o interactive || -t 0 ]]; then
                    read -q "REPLY?Continue anyway? [y/N] "
                    echo
                    [[ "$REPLY" != [Yy] ]] && return 1
                fi
            fi
            return 0
        fi
        total_size=$estimated_size
    else
        _diskguard_debug "Running deep check for ${(j:,:)sources}"
        total_size=$(_diskguard_deep_size "${sources[@]}")
    fi

    [[ "$total_size" =~ ^[0-9]+$ ]] || total_size=0
    _diskguard_debug "Total size: $(_diskguard_format_size $total_size)"

    #local available
    available=$(diskguard_df avail "$mountpoint")
    [[ "${available}" =~ ^[0-9]+$ ]] || available=0

    #local net_size
    net_size=$(( total_size - already_exists_size ))
    (( net_size < 0 )) && net_size=0

    total_space=$(diskguard_df size "$mountpoint")
    [[ "${total_space}" =~ ^[0-9]+$ ]] || total_space=0

    if (( net_size > available )); then
        printf '%s %s\n' "${DISKGUARD_COLOR_RED}❌ ERROR:${DISKGUARD_COLOR_NC} Not enough disk space on" "$mountpoint!" >&2
        printf '\n%s\t%s\n' "ℹ️ Required:" "$(_diskguard_format_size $total_size)" >&2
        printf '%s\t%s\n' "ℹ️ Available:" "$(_diskguard_format_size $available)" >&2
        printf '%s\t%s\n' "⚠️ Missing:" "${DISKGUARD_COLOR_YELLOW_BOLD}$(_diskguard_format_size $((total_size - available)))${DISKGUARD_COLOR_NC}" >&2
        return 1
    else
        local remaining usage_bytes
        remaining=$(($available - $net_size))
        remain_perc=$(( $remaining * 100 / ${total_space}))
        if (( $remain_perc >= 33 )) ; then
            remain_perc="${DISKGUARD_COLOR_GREEN}${remain_perc}%"
        elif
            (( $remain_perc < 33 )) && (( $remain_perc >= 15 )) ; then
            remain_perc="${DISKGUARD_COLOR_YELLOW_BOLD}${remain_perc}%"
        else
            remain_perc="${DISKGUARD_COLOR_RED}${remain_perc}%"
        fi

        usage_bytes=$((${total_space} - ${available}))
        if (( ${usage_perc} <= 66 )) ; then
            usage_perc="${DISKGUARD_COLOR_GREEN}${usage_perc}%${DISKGUARD_COLOR_NC}"
        elif (( ${usage_perc} > 66 )) && (( ${usage_perc} <= 85 )) ; then
            usage_perc="${DISKGUARD_COLOR_YELLOW_BOLD}${usage_perc}%${DISKGUARD_COLOR_NC}"
        else
            usage_perc="${DISKGUARD_COLOR_RED}${usage_perc}%${DISKGUARD_COLOR_NC}"
        fi
        printf '\n%s\t%s\t%s\n' "💾 Current usage:" "${usage_perc}" "$(_diskguard_format_size ${usage_bytes})" >&2
        printf '%s\t\t%s%%\t%s\n' "ℹ️ Available:" "$(( $available * 100 / $total_space ))" "$(_diskguard_format_size ${available})" >&2
        printf '%s\t\t%s%%\t%s\n' "ℹ️ Required:" "$(( $net_size * 100 / $available ))" "$(_diskguard_format_size ${net_size})" >&2
        [[ "${net_size}" != "0" ]] && printf '%s\t%s\t%s\n' "💾 Remaining space:" "${remain_perc}" "$(_diskguard_format_size ${remaining})${DISKGUARD_COLOR_NC}" >&2 || printf '%s\t%s\n' "💾 Remaining space:" "${DISKGUARD_COLOR_GREEN}available space will not change${DISKGUARD_COLOR_NC}" >&2
    fi

    if (( total_space > 0 )); then
        (( after_write = total_space - available + net_size ))
        (( usage_after = after_write * 100 / total_space ))
    else
        _diskguard_debug "Invalid total_space, skipping calculation."
        return 0
    fi

    if (( usage_after >= DISKGUARD_THRESHOLD )); then
        printf '⚠️\tWarning: Partition %s will be %s%% full!' "${mountpoint}" "${usage_after}" >&2
        printf '\tCurrent: %s%%\n' "${usage_perc}" >&2
        printf '\tAfter write: %s%% %s\n' "${usage_after}" "${after_write}" >&2
        printf '\tData size: %s\n' "$(_diskguard_format_size $net_size)" >&2

        if [[ -o interactive ]]; then
            read -q "REPLY?Continue anyway? [y/N] "
            echo
            [[ "$REPLY" != [Yy] ]] && return 1
        else
            return 1
        fi
    fi

    # Successfully completed
    printf '\n%s\t%s\n' "✅ Disk guard check:" "${DISKGUARD_COLOR_GREEN}passed${DISKGUARD_COLOR_NC}" >&2
    unset after_write remain_perc remaining available net_size total_size total_space usage_perc usage_bytes usage_after
    return 0
}

# ──────────────────────────────────────────────────────────────────
#  Plugin Management Functions
# ──────────────────────────────────────────────────────────────────

diskguard_enable() {
    DISKGUARD_ENABLED=1
    printf '%s\n' "${DISKGUARD_COLOR_GREEN}✓${DISKGUARD_COLOR_NC} DiskGuard enabled"
}

diskguard_disable() {
    DISKGUARD_ENABLED=0
    printf '%s\n' "${DISKGUARD_COLOR_RED}✓${DISKGUARD_COLOR_NC} DiskGuard disabled"
}

# ──────────────────────────────────────────────────────────────────
#  Installation - Create aliases for wrapped commands
# ──────────────────────────────────────────────────────────────────

for cmd in ${(z)DISKGUARD_COMMANDS}; do
    # Check if wrapper function exists
    if (( $+functions[_diskguard_${cmd}] )); then
        unalias $cmd 2>/dev/null
        alias $cmd="_diskguard_${cmd}"
    else
        print -P "%F{yellow}Warning: No wrapper for '${cmd}' - skipping%f" >&2
    fi
done

# ──────────────────────────────────────────────────────────────────
#  Cleanup Function - Unload plugin completely
# ──────────────────────────────────────────────────────────────────

diskguard_plugin_unload() {
    # Remove aliases (if any)
    if [[ -n "${DISKGUARD_COMMANDS:-}" ]]; then
        for cmd in ${(z)DISKGUARD_COMMANDS}; do
            unalias "$cmd" 2>/dev/null
        done
    fi

    # Unset functions
    unfunction -m '_diskguard_*' 2>/dev/null
    unfunction -m 'diskguard_*' 2>/dev/null

    unset DISKGUARD_{THRESHOLD,SCAN_THRESHOLD,DEBUG,ENABLED,COMMANDS}
    unset _diskguard_loaded
}

# ──────────────────────────────────────────────────────────────────
# DiskGuard: Help & Control
# ──────────────────────────────────────────────────────────────────
zshdg_help() {
  emulate -L zsh
  setopt LOCAL_OPTIONS
  clear 2>/dev/null || printf '\n'
    if [[ -f "${DISKGUARD_PLUGIN_DIR}/color" ]]; then
        local diskguard_color_toggle="toggle B/W mode"
        unset diskguard_color_capability
    else
        local diskguard_color_b=$'\e[0;34m' # blue
        local diskguard_color_c=$'\e[0;36m' # cyan
        local diskguard_color_g=$'\e[0;32m' # green
        local diskguard_color_m=$'\e[0;35m' # magenta
        local diskguard_color_r=$'\e[0;31m' # red
        local diskguard_color_y=$'\e[0;33m' # yellow
        local diskguard_color_n=$'\e[0m'    # reset
        local diskguard_color_toggle="toggle ${diskguard_color_y}c${diskguard_color_b}o${diskguard_color_c}l${diskguard_color_g}o${diskguard_color_r}r${diskguard_color_n} mode"
        local diskguard_color_capability="${DISKGUARD_COLOR_CYAN} colortest|--colortest${DISKGUARD_COLOR_NC}     → check the terminal's color capability"
    fi

  local title body body_lines
  title=("${DISKGUARD_COLOR_CYAN}DiskGuard Help Interface${DISKGUARD_COLOR_NC}")
  body_lines=("
Usage: ${DISKGUARD_COLOR_YELLOW_BOLD}zshdg ${DISKGUARD_COLOR_CYAN}<argument>${DISKGUARD_COLOR_NC}

Arguments:
    ${DISKGUARD_COLOR_CYAN} -s|--status|status${DISKGUARD_COLOR_NC}        → show plugin status
    ${DISKGUARD_COLOR_CYAN} -c|c|--color|color${DISKGUARD_COLOR_NC}        → ${diskguard_color_toggle}${DISKGUARD_COLOR_NC}")
[[ -n "${diskguard_color_capability}" ]] && body_lines+=("    ${diskguard_color_capability}${DISKGUARD_COLOR_NC}")
body_lines+=("
    ${DISKGUARD_COLOR_CYAN} -d|--default|default${DISKGUARD_COLOR_NC}      → load default values
    ${DISKGUARD_COLOR_CYAN} -t|--threshold 90${DISKGUARD_COLOR_NC}         → set ${DISKGUARD_COLOR_BLUE_DIM}DISK_GUARD_THRESHOLD=90${DISKGUARD_COLOR_NC}
                                 ${DISKGUARD_COLOR_GREY}and reload automatically${DISKGUARD_COLOR_NC}
    ${DISKGUARD_COLOR_CYAN} -st|--scan-threshold 500${DISKGUARD_COLOR_NC}  → set ${DISKGUARD_COLOR_BLUE_DIM}DISK_GUARD_SCAN_THRESHOLD=500${DISKGUARD_COLOR_NC}
                                 ${DISKGUARD_COLOR_GREY}and reload automatically${DISKGUARD_COLOR_NC}

    ${DISKGUARD_COLOR_CYAN} -r|--reload|reload${DISKGUARD_COLOR_NC}        → reload plugin
    ${DISKGUARD_COLOR_CYAN} -u|--unload|unload${DISKGUARD_COLOR_NC}        → unload plugin

    ${DISKGUARD_COLOR_CYAN} -e|--enable|enable${DISKGUARD_COLOR_NC}        → enable plugin
    ${DISKGUARD_COLOR_CYAN} -D|--disable|disable${DISKGUARD_COLOR_NC}      → disable plugin

    ${DISKGUARD_COLOR_CYAN} --debug|debug ${DISKGUARD_COLOR_NC}            → toggle debug mode on/off
  ")

    local IFS=$'\n'
    body="${body_lines[*]}"

    diskguard_print_box \
    ${title[@]} \
    ${body[@]}
}


if [[ -z $ZSH_DG_INTERFACE_DEFINED ]]; then
    typeset -g ZSH_DG_INTERFACE_DEFINED=1

    diskguard() {zshdg}
fi
    zshdg() {

        local cmd=$1
        [[ -z $1 ]] && { zshdg_help; return 0; }
        shift
        local plugin_file="${DISKGUARD_PLUGIN_DIR:-$ZPLUGINDIR/diskguard}/diskguard.zsh"

        case "$cmd" in
            -c|c|color|--color)
                whence -w diskguard_color &>/dev/null && diskguard_color
            ;;
            colortest|--colortest)
                whence -w colortest &>/dev/null && colortest
            ;;
            default|--default)
                whence -w diskguard_defaults &>/dev/null && diskguard_defaults
            ;;
            --debug|debug)
                if [[ -z "$DISKGUARD_DEBUG" || "${DISKGUARD_DEBUG}" == 0  ]] ; then
                    export DISKGUARD_DEBUG=1
                else
                    unset DISKGUARD_DEBUG
                fi
                ;;

            -r|--reload|reload)
                # Unload plugin cleanly if already loaded
                whence -w diskguard_plugin_unload &>/dev/null && diskguard_plugin_unload 2>/dev/null
                source "$plugin_file"
                printf '%s\n' "${DISKGUARD_COLOR_GREEN}[diskguard]${DISKGUARD_COLOR_NC} plugin reloaded."
                ;;

            -u|--unload|unload)
                whence -w diskguard_plugin_unload &>/dev/null && diskguard_plugin_unload
                clear
                printf " \x1b[35;2;255;100;0m╭───────────────────────────────────────────╮\n │ \x1b[32;2;255;100;0m[DiskGuard]\x1b[0m Plugin unloaded successfully. \x1b[35;2;255;100;0m│\n ╰───────────────────────────────────────────╯\n"
                ;;

            -e|--enable|enable)
                whence -w diskguard_enable &>/dev/null && diskguard_enable
                ;;

            -D|--disable|disable)
                whence -w diskguard_disable &>/dev/null && diskguard_disable
                ;;

            -h|help)
                whence -w zshdg_help &>/dev/null && zshdg_help
                ;;
            --help)
cat <<EOF
-d,--debug,debug
-c,--color,color
-r,--reload,reload
-s,--status,status
-u,--unload,unload
-e,--enable,enable
-D,--disable,disable
-t,--threshold,threshold
-st,--scan-threshold,scan-threshold
EOF
                ;;

            -s|-status|status)
                whence -w diskguard_status &>/dev/null && diskguard_status
                ;;
            -t|--threshold|threshold)
                # validate input first
                whence -w diskguard_validate_input_perc &>/dev/null && diskguard_validate_input_perc ${1}
                # then unload
                whence -w diskguard_plugin_unload &>/dev/null && diskguard_plugin_unload 2>/dev/null
                # THEN set the variable
                export DISKGUARD_THRESHOLD="${val}"
                # THEN reload
                source "$plugin_file"
                local title body
                title=("${DISKGUARD_COLOR_YELLOW_BOLD}DiskGuard${DISKGUARD_COLOR_NC}")
                footer=("Threshold updated to ${DISKGUARD_COLOR_CYAN}${DISKGUARD_THRESHOLD}%%${DISKGUARD_COLOR_NC}")
                diskguard_print_box \
                "${title[@]}" \
                "${footer}"
                unset val input
                diskguard_write_config
                return 0
                ;;
            -st|--scan-threshold|scan-threshold)
                # validate input first
                whence -w diskguard_validate_input_mb &>/dev/null && diskguard_validate_input_mb ${1}
                # then unload
                whence -w diskguard_plugin_unload &>/dev/null && diskguard_plugin_unload 2>/dev/null
                # THEN set the variable
                export DISKGUARD_SCAN_THRESHOLD="${val}"
                # THEN reload
                source "$plugin_file"
                local title body
                title=("${DISKGUARD_COLOR_YELLOW_BOLD}DiskGuard${DISKGUARD_COLOR_NC}")
                footer=("Scan threshold updated to ${DISKGUARD_COLOR_CYAN}${DISKGUARD_SCAN_THRESHOLD}%%${DISKGUARD_COLOR_NC}")
                diskguard_print_box \
                "${title[@]}" \
                "${footer}"
                unset val input
                diskguard_write_config
                return 0

            ;;
             *)
                 printf '%s\n' "Enter ${DISKGUARD_COLOR_CYAN}zshdg help${DISKGUARD_COLOR_NC} for help"
                 ;;
         esac
    }

    #compdef -k complete-word \C-x\C-r
