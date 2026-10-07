#!/usr/bin/env bash
#
# Timing runs for `dnm --desktop` (spec 001 SC-008 and the switcher's waits). Switches Desktops but never
# changes a wallpaper: it runs the switch-timing research tool, then times the real, read-only
# `dnm show --desktop N` for each start Desktop and target on every display, with a throwaway store.
#
# Needs: the Accessibility permission for the app running it, the "Move left/right a space" shortcuts on,
# and at least three Desktops on every display. Don't type or switch Desktops while it runs (about 10 to 15
# minutes with two displays). Each display is left on Desktop 1 afterwards.
#
# Usage: Tests/live/live-timing.sh [--dnm PATH] [--tool PATH] [--samples N] [--reps N] [--results DIR] [--dry-run] [--help]

set -euo pipefail

# Define color codes for terminal output
COLOR_GREEN="\e[32m"         # Used for success messages and instructions
COLOR_RED="\e[31m"           # Used for error messages and warnings
COLOR_YELLOW="\e[33m"        # Used for help text, lists, and informational content
COLOR_MAGENTA="\e[35m"       # Available for general use
COLOR_CYAN="\e[36m"          # Available for general use
COLOR_BLUE="\e[34m"          # Available for general use; does not show on screen well
COLOR_BRIGHTYELLOW="\e[93m"  # Used for highlighting important actions and status
COLOR_RESET="\e[0m"          # Used to reset color formatting

# Function to print colored output
print_colored() {
    local color=$1
    local message=$2
    printf "%b%s%b\n" "$color" "$message" "$COLOR_RESET"
}

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dnm_binary="${repository_root}/build.noindex/release/dnm"
timing_tool="${repository_root}/build.noindex/research/switch-timing"
results_directory="${repository_root}/working-notes/timing"
# In a copied test kit the binaries sit next to the Tests folder, with a results folder.
if [[ -x "${repository_root}/dnm" ]]; then
    dnm_binary="${repository_root}/dnm"
    timing_tool="${repository_root}/switch-timing"
    results_directory="${repository_root}/results"
fi
samples=20
repetitions=3
highest_desktop=3
dry_run=false
scratch_store=""

usage() {
    print_colored "$COLOR_YELLOW" "Usage: Tests/live/live-timing.sh [--dnm PATH] [--tool PATH] [--samples N] [--reps N] [--results DIR] [--dry-run] [--help]"
    print_colored "$COLOR_YELLOW" "  --dnm PATH      the dnm binary (default: build.noindex/release/dnm, or ./dnm in a kit)"
    print_colored "$COLOR_YELLOW" "  --tool PATH     the switch-timing tool (default: build.noindex/research/switch-timing, or ./switch-timing in a kit)"
    print_colored "$COLOR_YELLOW" "  --samples N     steps per measurement in switch-timing (default 20)"
    print_colored "$COLOR_YELLOW" "  --reps N        repetitions of each dnm show --desktop timing (default 3)"
    print_colored "$COLOR_YELLOW" "  --results DIR   where to write the logs and CSV files (default: working-notes/timing, or ./results in a kit)"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n   print the steps without switching Desktops"
    print_colored "$COLOR_YELLOW" "Switches Desktops (no wallpaper changes). Run only while idle, and don't type while it runs."
}

# Run a command, or only print it in dry-run mode.
run_step() {
    if "$dry_run"; then
        print_colored "$COLOR_CYAN" "[dry run] $*"
    else
        "$@"
    fi
}

now_milliseconds() {
    # macOS's bash 3.2 has no EPOCHREALTIME; perl ships with macOS.
    perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'
}

cleanup() {
    if [[ -n "$scratch_store" ]]; then
        rm -rf "$scratch_store"
    fi
}

accessibility_granted() {
    # Capture first: with pipefail, `dnm check | grep -q` fails when grep exits early and dnm gets SIGPIPE.
    local report
    report="$("$dnm_binary" check)"
    grep -q '^ok  Accessibility' <<<"$report"
}

connected_displays() {
    # One name per line: "main", then the other displays as `dnm displays` lists them.
    local listing
    listing="$("$dnm_binary" displays)"
    printf "%s\n" "main"
    grep -v '(main)$' <<<"$listing" | sed 's/ *$//' || true
}

display_for_tool() {
    # switch-timing takes "main" or a unique part of a display's name.
    printf "%s" "$1"
}

check_three_desktops_each() {
    # Reaching Desktop 3 read-only (show switches there and back) proves each display has enough Desktops,
    # before the long run starts. macOS moves Desktops between displays when monitors change.
    local display_name problem
    while IFS= read -r display_name; do
        print_colored "$COLOR_YELLOW" "Checking that ${display_name} has a Desktop 3..."
        if ! problem="$("$dnm_binary" show --display "$display_name" --desktop 3 2>&1 >/dev/null)"; then
            print_colored "$COLOR_RED" "${problem}"
            print_colored "$COLOR_RED" "Give every display at least three Desktops (Mission Control, +), then run this again."
            return 1
        fi
    done < <(connected_displays)
}

time_show() {
    # time_show <display> <start> <target> <rep>: one timed `dnm show --desktop`, as a CSV row.
    local display_name=$1 start_desktop=$2 target_desktop=$3 repetition=$4
    local start_milliseconds elapsed_milliseconds exit_status=0
    start_milliseconds="$(now_milliseconds)"
    "$dnm_binary" show --display "$display_name" --desktop "$target_desktop" >/dev/null 2>&1 || exit_status=$?
    elapsed_milliseconds=$(($(now_milliseconds) - start_milliseconds))
    printf "%s,\"%s\",%s,%s,%s,%s,%s\n" "$run_context" "$display_name" "$start_desktop" "$target_desktop" \
        "$repetition" "$elapsed_milliseconds" "$exit_status" >>"$dnm_csv"
    printf "  %s: start %s -> Desktop %s, run %s: %s ms%s\n" "$display_name" "$start_desktop" "$target_desktop" \
        "$repetition" "$elapsed_milliseconds" "$( ((exit_status == 0)) || printf ' (exit %s)' "$exit_status")"
}

summarize_dnm_timings() {
    # Median and maximum per display, start and target, from this run's rows, checked against spec 001
    # SC-008: 2.5 s plus 1.25 s per step. Steps: left to Desktop 1 (start - 1), the step right and back
    # that only --desktop 1 from Desktop 1 needs (2), right to the target (target - 1), back (|target - start|).
    print_colored "$COLOR_BRIGHTYELLOW" "dnm show --desktop: median / max ms per start -> target, against SC-008"
    awk -F, -v context="$run_context" '
        index($0, context) == 1 {
            key = $(NF-5) " start " $(NF-4) " -> " $(NF-3)
            values[key] = values[key] " " $(NF-1)
            if ($(NF-1) > maximum[key]) maximum[key] = $(NF-1)
            start = $(NF-4) + 0; target = $(NF-3) + 0
            distance = target - start; if (distance < 0) distance = -distance
            steps[key] = (start - 1) + ((start == 1 && target == 1) ? 2 : 0) + (target - 1) + distance
        }
        END {
            for (key in values) {
                count = split(values[key], list, " ")
                # Simple sort for a few values.
                for (i = 1; i <= count; i++) for (j = i + 1; j <= count; j++) if (list[j] + 0 < list[i] + 0) { t = list[i]; list[i] = list[j]; list[j] = t }
                limit = 2500 + 1250 * steps[key]
                printf "  %s: %d / %d (%d steps, limit %d) %s\n", key, list[int((count + 1) / 2)], maximum[key], steps[key], limit, (maximum[key] <= limit ? "PASS" : "FAIL")
            }
        }' "$dnm_csv" | sort
}

while (($# > 0)); do
    case "$1" in
        --dnm) dnm_binary="${2:?--dnm needs a path}"; shift 2 ;;
        --tool) timing_tool="${2:?--tool needs a path}"; shift 2 ;;
        --samples) samples="${2:?--samples needs a number}"; shift 2 ;;
        --reps) repetitions="${2:?--reps needs a number}"; shift 2 ;;
        --results) results_directory="${2:?--results needs a folder}"; shift 2 ;;
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

[[ "$samples" =~ ^[0-9]+$ && "$repetitions" =~ ^[0-9]+$ ]] || { print_colored "$COLOR_RED" "--samples and --reps take whole numbers."; exit 2; }

if ! "$dry_run"; then
    [[ -x "$dnm_binary" ]] || { print_colored "$COLOR_RED" "No executable at ${dnm_binary}. Run: just release"; exit 1; }
    [[ -x "$timing_tool" ]] || { print_colored "$COLOR_RED" "No executable at ${timing_tool}. Build it: swiftc -O -o build.noindex/research/switch-timing prototype/switch-timing.swift"; exit 1; }
    command -v perl >/dev/null || { print_colored "$COLOR_RED" "perl is needed to time the commands."; exit 1; }
    if ! accessibility_granted; then
        print_colored "$COLOR_RED" "The app running this script does not have the Accessibility permission. Run ./dnm check (or dnm check) to see where to grant it. Nothing was changed."
        exit 1
    fi
    mkdir -p "$results_directory"
    # show never changes a wallpaper; a throwaway store keeps even its cleanup away from real labels.
    scratch_store="$(mktemp -d "${TMPDIR:-/tmp}/dnm-timing.XXXXXX")"
    export DNM_STORE_DIR="$scratch_store"
    trap cleanup EXIT
    read -r -p "This switches Desktops for about 10 to 15 minutes (no wallpaper changes). Are you idle, with at least 3 Desktops on each display? [y/N] " confirm
    [[ "$confirm" == [yY]* ]] || { print_colored "$COLOR_RED" "Cancelled."; exit 1; }
fi

display_count="?"
if ! "$dry_run"; then
    display_count="$("$dnm_binary" displays | wc -l | tr -d ' ')"
fi
run_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_context="${run_stamp},$(sw_vers -productVersion),$(uname -m),${display_count}"
dnm_csv="${results_directory}/dnm-timing.csv"
tool_csv="${results_directory}/switch-timing.csv"
tool_log="${results_directory}/switch-timing-${display_count}displays-${run_stamp}.txt"

if ! "$dry_run"; then
    print_colored "$COLOR_YELLOW" "Run on: macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(uname -m), ${display_count} display(s), dnm $("$dnm_binary" --version), ${run_stamp}"
fi

if ! "$dry_run"; then
    check_three_desktops_each
fi

# --- Part 1: step timing (switch-timing) -------------------------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Part 1: step timing on every display (${samples} samples each)"
if "$dry_run"; then
    run_step "$timing_tool" --samples "$samples" --csv "$tool_csv"
else
    "$timing_tool" --samples "$samples" --csv "$tool_csv" | tee "$tool_log"
fi

# --- Part 2: dnm show --desktop, every start and target ----------------------------------------------
print_colored "$COLOR_BRIGHTYELLOW" "Part 2: dnm show --desktop for start Desktops 1-${highest_desktop} and targets 1-${highest_desktop} (${repetitions} runs each)"
if ! "$dry_run" && [[ ! -f "$dnm_csv" ]]; then
    printf "run,macos,arch,displays,display,start,target,rep,ms,exit\n" >"$dnm_csv"
fi
while IFS= read -r display_name; do
    if "$dry_run"; then
        run_step "$timing_tool" --display "$display_name" --goto 1
        run_step "$dnm_binary" show --display "$display_name" --desktop 1
        continue
    fi
    for start_desktop in $(seq 1 "$highest_desktop"); do
        "$timing_tool" --display "$(display_for_tool "$display_name")" --goto "$start_desktop"
        for target_desktop in $(seq 1 "$highest_desktop"); do
            for repetition in $(seq 1 "$repetitions"); do
                time_show "$display_name" "$start_desktop" "$target_desktop" "$repetition"
            done
        done
    done
    "$timing_tool" --display "$(display_for_tool "$display_name")" --goto 1
done < <(connected_displays)

if ! "$dry_run"; then
    summarize_dnm_timings | tee -a "$tool_log"
    print_colored "$COLOR_GREEN" "Done. Results: ${tool_log}, ${tool_csv}, ${dnm_csv}"
    print_colored "$COLOR_YELLOW" "Each display was left on Desktop 1; switch back if you like."
fi
