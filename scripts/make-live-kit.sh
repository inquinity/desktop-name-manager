#!/usr/bin/env bash
#
# Assemble a folder you can copy to another Mac (by USB stick or similar) to run the live checks there.
# It builds a universal (Apple silicon and Intel) release of dnm and collects the live scripts, the
# quickstart and instructions. The build is for testing only: it is not Developer ID signed or notarized.
#
# Usage: scripts/make-live-kit.sh [--output DIR] [--dry-run] [--help]
# Default output: dist/dnm-live-kit (dist/ is ignored by git).

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

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="${repository_root}/dist/dnm-live-kit"
dry_run=false

usage() {
    print_colored "$COLOR_YELLOW" "Usage: scripts/make-live-kit.sh [--output DIR] [--dry-run] [--help]"
    print_colored "$COLOR_YELLOW" "  --output DIR   where to put the kit (default: dist/dnm-live-kit; it is replaced if it exists)"
    print_colored "$COLOR_YELLOW" "  --dry-run, -n  print what would be done without building or writing"
    print_colored "$COLOR_YELLOW" "Builds a universal dnm and collects the live scripts and instructions to copy to another Mac."
}

while (($# > 0)); do
    case "$1" in
        --output) output_directory="${2:?--output needs a folder}"; shift 2 ;;
        -n|--dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_colored "$COLOR_RED" "Unknown option: $1"; usage; exit 2 ;;
    esac
done

# Never replace a folder that is not a kit we made (guards against a mistyped --output).
if [[ -e "$output_directory" && ! -f "${output_directory}/BUILD-INFO.txt" ]]; then
    print_colored "$COLOR_RED" "${output_directory} exists and is not a kit made by this script; refusing to replace it."
    exit 1
fi

commit="$(git -C "$repository_root" rev-parse --short HEAD)"
dirty=""
if [[ -n "$(git -C "$repository_root" status --porcelain)" ]]; then
    dirty=" (with uncommitted changes)"
fi

if "$dry_run"; then
    print_colored "$COLOR_CYAN" "[dry run] would build: swift build -c release --arch arm64 --arch x86_64 --product dnm"
    print_colored "$COLOR_CYAN" "[dry run] would write the kit for commit ${commit}${dirty} to ${output_directory}"
    exit 0
fi

print_colored "$COLOR_BRIGHTYELLOW" "Building a universal release of dnm (commit ${commit}${dirty})..."
(cd "$repository_root" && swift build -c release --arch arm64 --arch x86_64 --product dnm)
built_binary="${repository_root}/.build/out/Products/Release/dnm"
[[ -x "$built_binary" ]] || { print_colored "$COLOR_RED" "Cannot find the built binary at ${built_binary}"; exit 1; }
architectures="$(lipo -archs "$built_binary")"
[[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]] || {
    print_colored "$COLOR_RED" "The binary is not universal (found: ${architectures})."
    exit 1
}

rm -rf "$output_directory"
mkdir -p "${output_directory}/Tests/live" "${output_directory}/results"
cp "$built_binary" "${output_directory}/dnm"
cp "${repository_root}/Tests/live/live-label.sh" "${repository_root}/Tests/live/live-safety.sh" "${output_directory}/Tests/live/"
cp "${repository_root}/specs/001-labels-and-cli/quickstart.md" "${output_directory}/quickstart.md"
chmod +x "${output_directory}/dnm" "${output_directory}"/Tests/live/*.sh

binary_checksum="$(shasum -a 256 "${output_directory}/dnm" | awk '{print $1}')"
cat >"${output_directory}/BUILD-INFO.txt" <<EOF
dnm live-test kit
Version:        $("${output_directory}/dnm" --version)
Source commit:  ${commit}${dirty}
Built (UTC):    $(date -u +%Y-%m-%dT%H:%M:%SZ)
Architectures:  ${architectures}
Minimum macOS:  26.0
Toolchain:      $(swift --version 2>&1 | head -n 1)
SHA-256 of dnm: ${binary_checksum}
Signing:        ad hoc only. Not Developer ID signed, not notarized. For testing only.
EOF

cat >"${output_directory}/README-FIRST.md" <<'EOF'
# dnm live-test kit

This folder lets you test the `dnm` command-line tool on this Mac. It changes the wallpaper of the
Desktop you are on, for a few seconds at a time, and puts it back. It is a test build: not signed or
notarized, and not for installing.

## Before you start

- macOS 26 or later. Any Mac, Intel or Apple silicon.
- Be at the Mac, idle, and on the Desktop you want to label.
- In System Settings > Wallpaper, turn OFF "Show on all Spaces".
- Labels go to the MAIN display (the one with the menu bar). Watch that screen.

## Steps

1. Copy this whole folder to the Mac (a USB stick is fine). Put it somewhere simple, such as the home folder.
2. Open Terminal and go to the folder:

   ```sh
   cd path/to/dnm-live-kit
   ```

   If macOS says the files cannot be opened (this happens when they came by AirDrop or download rather
   than USB), run this once, then try again:

   ```sh
   xattr -dr com.apple.quarantine .
   ```

3. Check that it runs:

   ```sh
   ./dnm --version
   ./dnm displays
   ```

4. Run the main live check. It asks you to confirm, then pauses at each "LOOK:" prompt for you to look
   at the screen and answer `y` or `n`. If you answer `n`, write down what you saw.

   ```sh
   Tests/live/live-label.sh 2>&1 | tee results/live-label.txt
   ```

5. Run the safety check. It asks you to switch to a dynamic or aerial wallpaper, and to a wallpaper in a
   protected folder (for example one inside Documents), at the points where it pauses.

   ```sh
   Tests/live/live-safety.sh 2>&1 | tee results/live-safety.txt
   ```

6. Optional, from `quickstart.md`: scenario 4 (reorder Desktops, use Show Desktop, then log out and in and
   confirm a label is still on the same Desktop), scenario 17 (a solid-color wallpaper) and scenario 18
   (look closely for any loss of picture quality away from the label). Write your results in
   `results/notes.txt`.

   To label by hand: `./dnm set "Test"`, wait a few seconds, then `./dnm remove`.

7. Copy the whole folder back (the `results` folder matters most).

## If something looks wrong

Each script makes a backup of your wallpaper store in a temporary folder and prints the command to
restore it. `./dnm remove` puts the original wallpaper back for the Desktop you are on. The backups
live in your temporary folder (`$TMPDIR`) and are deleted when you restart; delete them yourself sooner
if you like.

`BUILD-INFO.txt` says which source commit this build came from.
EOF

(cd "$output_directory" && shasum -a 256 dnm Tests/live/live-label.sh Tests/live/live-safety.sh >SHA256SUMS)
print_colored "$COLOR_GREEN" "Kit written to ${output_directory}"
print_colored "$COLOR_GREEN" "Copy that whole folder to the other Mac and follow README-FIRST.md inside it."
