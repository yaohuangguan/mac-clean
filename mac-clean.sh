#!/bin/bash

# macOS Safe Interactive Cleaner
# - Default answer: YES ([Y/n])
# - Only removes disposable caches/logs that can be regenerated.
# - Does NOT remove source code, Xcode Archives, iOS DeviceSupport,
#   Simulator devices/data, Docker data, iPhone backups, Time Machine snapshots,
#   /System, or arbitrary Application Support / Containers data.
#
# Source:
#   https://github.com/yaohuangguan/mac-clean
#
# Designed to work with:
#   curl -fsSL https://assets.samyao.me/uploads/scripts/mac-clean.sh | bash

set -u
set -o pipefail

TTY="/dev/tty"

if [[ ! -r "$TTY" ]]; then
  echo "Error: no interactive terminal available. Run this from macOS Terminal."
  exit 1
fi

if [[ -t 1 ]]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  RED='\033[31m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  CYAN='\033[36m'
  RESET='\033[0m'
else
  BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
fi

say() { printf "%b\n" "$*"; }

hr() {
  local cols
  cols="$(tput cols 2>/dev/null || echo 72)"
  printf '%*s\n' "$cols" '' | tr ' ' '-'
}

ask_yes() {
  local prompt="$1"
  local answer=""
  printf "%b%s%b [Y/n]: " "$BOLD" "$prompt" "$RESET" > "$TTY"
  IFS= read -r answer < "$TTY" || answer=""
  case "$answer" in
    n|N|no|NO|No) return 1 ;;
    *) return 0 ;;
  esac
}

size_kb() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sk "$path" 2>/dev/null | awk 'NR==1 {print $1+0}'
  else
    echo 0
  fi
}

format_kb() {
  awk -v kb="${1:-0}" 'BEGIN {
    if (kb >= 1073741824)      printf "%.2f TB", kb/1073741824;
    else if (kb >= 1048576)    printf "%.2f GB", kb/1048576;
    else if (kb >= 1024)       printf "%.2f MB", kb/1024;
    else                       printf "%.0f KB", kb;
  }'
}

free_kb() {
  df -Pk / 2>/dev/null | awk 'NR==2 {print $4+0}'
}

clean_dir_contents() {
  local path="$1"
  [[ -d "$path" ]] || return 0
  find "$path" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
}

SUMMARY_LABELS=()
SUMMARY_KB=()
TOTAL_LOGICAL_KB=0

add_summary() {
  local label="$1"
  local reclaimed="$2"
  local idx="${#SUMMARY_LABELS[@]}"
  SUMMARY_LABELS[$idx]="$label"
  SUMMARY_KB[$idx]="$reclaimed"
  TOTAL_LOGICAL_KB=$((TOTAL_LOGICAL_KB + reclaimed))
}

offer_clean_dir() {
  local label="$1"
  local path="$2"
  local note="${3:-}"
  local before after reclaimed

  before="$(size_kb "$path")"
  printf "  %-34s %10s  %s\n" "$label" "$(format_kb "$before")" "$path"

  if (( before <= 0 )); then
    say "  ${DIM}Nothing to clean.${RESET}"
    return 0
  fi

  if [[ -n "$note" ]]; then
    say "  ${DIM}${note}${RESET}"
  fi

  if ask_yes "Delete ${label}?"; then
    clean_dir_contents "$path"
    after="$(size_kb "$path")"
    reclaimed=$((before - after))
    (( reclaimed < 0 )) && reclaimed=0
    add_summary "$label" "$reclaimed"
    say "  ${GREEN}✓ Cleaned $(format_kb "$reclaimed")${RESET}"
  else
    say "  ${DIM}Skipped${RESET}"
  fi
}

record_command_cleanup() {
  # Usage: record_command_cleanup "label" "size-path" command arg...
  local label="$1"
  local path="$2"
  shift 2
  local before after reclaimed

  before="$(size_kb "$path")"
  printf "  %-34s %10s  %s\n" "$label" "$(format_kb "$before")" "$path"

  if (( before <= 0 )); then
    say "  ${DIM}Nothing to clean.${RESET}"
    return 0
  fi

  if ask_yes "Clean ${label}?"; then
    "$@" >/dev/null 2>&1 || true
    after="$(size_kb "$path")"
    reclaimed=$((before - after))
    (( reclaimed < 0 )) && reclaimed=0
    add_summary "$label" "$reclaimed"
    say "  ${GREEN}✓ Cleaned $(format_kb "$reclaimed")${RESET}"
  else
    say "  ${DIM}Skipped${RESET}"
  fi
}

START_FREE_KB="$(free_kb)"
START_EPOCH="$(date +%s)"

clear 2>/dev/null || true
say "${BOLD}${CYAN}macOS Safe Interactive Cleaner${RESET}"
say "Default is ${BOLD}YES${RESET}: press Enter to clean, type ${BOLD}n${RESET} to skip."
say ""
say "${GREEN}Safe-clean policy:${RESET} only disposable caches/logs are removed."
say "${YELLOW}Not touched:${RESET} source code, Git repos, Xcode Archives, DeviceSupport,"
say "Simulator devices/data, Docker images/containers/volumes, iPhone backups,"
say "Time Machine snapshots, Application Support, Containers, /System and user documents."
hr
say "Disk before cleanup:"
df -h / 2>/dev/null | tail -1

# -----------------------------------------------------------------------------
# 1. General per-user caches
# -----------------------------------------------------------------------------
hr
say "${BOLD}1) macOS / app caches${RESET}"
offer_clean_dir \
  "User app caches" \
  "$HOME/Library/Caches" \
  "Apps recreate these as needed; first launch may be slightly slower."

# -----------------------------------------------------------------------------
# 2. User logs
# -----------------------------------------------------------------------------
hr
say "${BOLD}2) User logs${RESET}"
offer_clean_dir \
  "User logs" \
  "$HOME/Library/Logs" \
  "Diagnostic logs only; apps/macOS will create new logs later."

# -----------------------------------------------------------------------------
# 3. Xcode safe cache only
# -----------------------------------------------------------------------------
hr
say "${BOLD}3) Xcode build cache${RESET}"
say "${DIM}Only DerivedData is eligible. Archives, DeviceSupport and Simulators are preserved.${RESET}"
offer_clean_dir \
  "Xcode DerivedData" \
  "$HOME/Library/Developer/Xcode/DerivedData" \
  "Does not delete projects or Archives; Xcode will rebuild on the next compile."

# -----------------------------------------------------------------------------
# 4. npm cache (~/.npm) - not normally inside ~/Library/Caches
# -----------------------------------------------------------------------------
hr
say "${BOLD}4) JavaScript package caches${RESET}"
if command -v npm >/dev/null 2>&1; then
  NPM_CACHE="$(npm config get cache 2>/dev/null || true)"
  if [[ -n "$NPM_CACHE" && "$NPM_CACHE" != "undefined" ]]; then
    record_command_cleanup "npm cache" "$NPM_CACHE" npm cache clean --force
  fi
else
  say "  ${DIM}npm not installed; skipped.${RESET}"
fi

# pnpm prune only removes packages no longer referenced by the store metadata.
if command -v pnpm >/dev/null 2>&1; then
  PNPM_STORE="$(pnpm store path 2>/dev/null || true)"
  if [[ -n "$PNPM_STORE" && -d "$PNPM_STORE" ]]; then
    before="$(size_kb "$PNPM_STORE")"
    printf "  %-34s %10s  %s\n" "pnpm unused store data" "$(format_kb "$before")" "$PNPM_STORE"
    say "  ${DIM}Prunes unreferenced package data; projects and node_modules are not deleted.${RESET}"
    if (( before > 0 )) && ask_yes "Prune unused pnpm store data?"; then
      pnpm store prune >/dev/null 2>&1 || true
      after="$(size_kb "$PNPM_STORE")"
      reclaimed=$((before - after))
      (( reclaimed < 0 )) && reclaimed=0
      add_summary "pnpm unused store data" "$reclaimed"
      say "  ${GREEN}✓ Cleaned $(format_kb "$reclaimed")${RESET}"
    elif (( before > 0 )); then
      say "  ${DIM}Skipped${RESET}"
    fi
  fi
fi

# -----------------------------------------------------------------------------
# 5. Python pip cache
# -----------------------------------------------------------------------------
hr
say "${BOLD}5) Python package cache${RESET}"
if command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
  PIP_CACHE="$(python3 -m pip cache dir 2>/dev/null || true)"
  if [[ -n "$PIP_CACHE" && -d "$PIP_CACHE" ]]; then
    record_command_cleanup "pip download/build cache" "$PIP_CACHE" python3 -m pip cache purge
  else
    say "  ${DIM}No pip cache found.${RESET}"
  fi
else
  say "  ${DIM}python3/pip not available; skipped.${RESET}"
fi

# -----------------------------------------------------------------------------
# 6. Gradle cache (safe but causes dependency re-download / rebuild)
# -----------------------------------------------------------------------------
hr
say "${BOLD}6) Gradle cache${RESET}"
if [[ -d "$HOME/.gradle/caches" ]]; then
  offer_clean_dir \
    "Gradle caches" \
    "$HOME/.gradle/caches" \
    "Projects are preserved; Gradle may re-download dependencies and rebuild next time."
else
  say "  ${DIM}No Gradle cache found.${RESET}"
fi

# -----------------------------------------------------------------------------
# 7. Homebrew downloaded cache only; keep installed/current and old kegs untouched.
# -----------------------------------------------------------------------------
hr
say "${BOLD}7) Homebrew download cache${RESET}"
if command -v brew >/dev/null 2>&1; then
  BREW_CACHE="$(brew --cache 2>/dev/null || true)"
  if [[ -n "$BREW_CACHE" && -d "$BREW_CACHE" ]]; then
    offer_clean_dir \
      "Homebrew downloaded cache" \
      "$BREW_CACHE" \
      "Installed formulae/casks are not removed; downloads can be fetched again."
  else
    say "  ${DIM}No Homebrew cache found.${RESET}"
  fi
else
  say "  ${DIM}Homebrew not installed; skipped.${RESET}"
fi

# -----------------------------------------------------------------------------
# 8. Safe report-only areas
# -----------------------------------------------------------------------------
hr
say "${BOLD}8) Large areas intentionally NOT deleted${RESET}"
say "These can contain real development/user state, so this script reports them only."

report_path() {
  local label="$1"
  local path="$2"
  local kb
  kb="$(size_kb "$path")"
  printf "  %-34s %10s  %s\n" "$label" "$(format_kb "$kb")" "$path"
}

report_path "Xcode Archives" "$HOME/Library/Developer/Xcode/Archives"
report_path "iOS DeviceSupport" "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
report_path "CoreSimulator" "$HOME/Library/Developer/CoreSimulator"
report_path "iPhone/iPad backups" "$HOME/Library/Application Support/MobileSync/Backup"
report_path "Application Support" "$HOME/Library/Application Support"
report_path "App Containers" "$HOME/Library/Containers"
report_path "Group Containers" "$HOME/Library/Group Containers"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  say ""
  say "${BOLD}Docker usage (report only):${RESET}"
  docker system df 2>/dev/null || true
fi

say ""
say "${BOLD}Largest folders in ~/Library (report only):${RESET}"
du -hd 1 "$HOME/Library" 2>/dev/null | sort -h | tail -12 || true

# -----------------------------------------------------------------------------
# Final summary
# -----------------------------------------------------------------------------
END_FREE_KB="$(free_kb)"
END_EPOCH="$(date +%s)"
FREE_DELTA_KB=$((END_FREE_KB - START_FREE_KB))
ELAPSED=$((END_EPOCH - START_EPOCH))

hr
say "${BOLD}${CYAN}Cleanup summary${RESET}"

if (( ${#SUMMARY_LABELS[@]} == 0 )); then
  say "No cleanup items were removed."
else
  i=0
  while (( i < ${#SUMMARY_LABELS[@]} )); do
    printf "  %-36s %10s\n" "${SUMMARY_LABELS[$i]}" "$(format_kb "${SUMMARY_KB[$i]}")"
    i=$((i + 1))
  done
  hr
  printf "  %-36s %10s\n" "Logical data removed" "$(format_kb "$TOTAL_LOGICAL_KB")"
fi

if (( FREE_DELTA_KB >= 0 )); then
  printf "  %-36s %10s\n" "Filesystem free-space increase" "$(format_kb "$FREE_DELTA_KB")"
else
  printf "  %-36s %10s\n" "Filesystem free-space change" "-$(format_kb "$((-FREE_DELTA_KB))")"
fi
printf "  %-36s %9ss\n" "Elapsed" "$ELAPSED"

say ""
say "Disk after cleanup:"
df -h / 2>/dev/null | tail -1

say ""
say "${DIM}Note: 'Logical data removed' is measured from the cleaned directories."
say "APFS purgeable space, swap activity, open files and background apps can make the"
say "actual free-space delta differ. macOS Storage/System Data may also update later.${RESET}"
