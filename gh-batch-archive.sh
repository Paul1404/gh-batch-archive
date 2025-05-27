#!/usr/bin/env bash

set -euo pipefail

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- DEFAULTS ---
LOGFILE="gh-batch-archive.log"
PARALLEL=4
FZF_HEIGHT=20

# --- USAGE ---
usage() {
    echo -e "${BOLD}${CYAN}GitHub Batch Archive Tool${NC}"
    echo "Batch archive or unarchive repositories with maximum clarity and safety."
    echo
    echo -e "${BOLD}Usage:${NC}"
    echo "  $0 [options] [owner_or_org]"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  --unarchive         Unarchive instead of archive"
    echo "  --dry-run           Show what would be done, but don't change anything"
    echo "  --pattern PATTERN   Filter repos by substring or regex"
    echo "  --interactive       Use interactive selection (fzf if available, fallback to menu)"
    echo "  --parallel N        Process up to N repos in parallel (default: $PARALLEL)"
    echo "  --log FILE          Log actions to FILE (default: $LOGFILE)"
    echo "  --help              Show this help message"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  $0 --pattern test myorg"
    echo "  $0 --unarchive --interactive"
    echo "  $0 --dry-run --parallel 8"
}

# --- DEPENDENCY CHECKS ---
require_gh() {
    command -v gh >/dev/null 2>&1 || {
        echo -e "${RED}❌ Error:${NC} The GitHub CLI ('gh') is required. Please install it from https://cli.github.com/"
        exit 1
    }
}

has_fzf() {
    command -v fzf >/dev/null 2>&1
}

# --- ARGUMENT PARSING ---
UNARCHIVE=false
DRY_RUN=false
PATTERN=""
INTERACTIVE=false
OWNER=""
LOG="$LOGFILE"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --unarchive) UNARCHIVE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --pattern) PATTERN="$2"; shift 2 ;;
        --interactive) INTERACTIVE=true; shift ;;
        --parallel) PARALLEL="$2"; shift 2 ;;
        --log) LOG="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        *) OWNER="$1"; shift ;;
    esac
done

require_gh

# --- GET OWNER IF NOT PROVIDED ---
if [[ -z "$OWNER" ]]; then
    OWNER="$(gh api user --jq .login)"
    echo -e "${CYAN}ℹ️  No owner or organization specified. Using your GitHub username: '${OWNER}'.${NC}"
else
    echo -e "${CYAN}ℹ️  Using specified owner/organization: '${OWNER}'.${NC}"
fi

# --- FETCH REPOS ---
echo -e "${CYAN}🔎 Searching for non-archived repositories owned by '${OWNER}'...${NC}"
REPOS=$(gh repo list "$OWNER" --no-archived --limit 1000 --json nameWithOwner \
    --jq '.[].nameWithOwner')

if [[ -z "$REPOS" ]]; then
    echo -e "${YELLOW}⚠️  No non-archived repositories found for '${OWNER}'. Nothing to do.${NC}"
    exit 0
fi

# --- FILTER BY PATTERN ---
if [[ -n "$PATTERN" ]]; then
    echo -e "${CYAN}🔍 Filtering repositories by pattern: '${PATTERN}'...${NC}"
    REPOS=$(echo "$REPOS" | grep -E "$PATTERN" || true)
    if [[ -z "$REPOS" ]]; then
        echo -e "${YELLOW}⚠️  No repositories match the pattern '${PATTERN}'. Exiting.${NC}"
        exit 0
    fi
fi

# --- INTERACTIVE SELECTION ---
select_repos() {
    local repos="$1"
    if has_fzf; then
        echo -e "${CYAN}🖱️  Interactive selection enabled. Use TAB to select multiple repositories, then press ENTER to confirm your choices.${NC}"
        echo "$repos" | fzf --multi --prompt="Select repos> " --height="$FZF_HEIGHT"
    else
        echo -e "${YELLOW}⚠️  'fzf' not found. Falling back to a simple numbered menu.${NC}"
        local arr=()
        local i=1
        while IFS= read -r repo; do
            arr+=("$repo")
            echo "  [$i] $repo"
            ((i++))
        done <<< "$repos"
        echo
        echo -e "${CYAN}Please enter the numbers of the repositories you want to select, separated by spaces (e.g. 1 3 5):${NC}"
        read -r choices
        for n in $choices; do
            [[ "$n" =~ ^[0-9]+$ ]] && echo "${arr[$((n-1))]}"
        done
    fi
}

if $INTERACTIVE; then
    SELECTED="$(select_repos "$REPOS")"
else
    SELECTED="$REPOS"
fi

if [[ -z "$SELECTED" ]]; then
    echo -e "${YELLOW}⚠️  No repositories selected. Exiting without making any changes.${NC}"
    exit 0
fi

# --- EXPLICIT ACTION SUMMARY ---
ACTION="archive"
if $UNARCHIVE; then
    ACTION="unarchive"
fi

MODE="ACTUAL"
if $DRY_RUN; then
    MODE="DRY-RUN (no changes will be made)"
fi

REPO_COUNT=$(echo "$SELECTED" | grep -c .)

echo
echo -e "${CYAN}==============================${NC}"
echo -e "${BOLD}${CYAN}SUMMARY:${NC}"
echo -e "You are about to ${BOLD}${ACTION}${NC} ${BOLD}${REPO_COUNT}${NC} repositories owned by ${BOLD}${OWNER}${NC}."
echo -e "Mode: ${YELLOW}${MODE}${NC}"
echo -e "The following repositories will be affected:"
echo "$SELECTED" | nl -w2 -s'. '
echo -e "${CYAN}==============================${NC}"
echo

if $DRY_RUN; then
    echo -e "${YELLOW}📝 This is a dry-run. No changes will be made.${NC}"
else
    read -r -p "$(echo -e "${BOLD}❓ Do you want to proceed and ${ACTION} these repositories? [y/N] ${NC}")" CONFIRM
    if ! [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Operation cancelled by user. No changes made.${NC}"
        exit 0
    fi
fi

# --- ARCHIVE/UNARCHIVE FUNCTION ---
process_repo() {
    local repo="$1"
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would ${UNARCHIVE:+un}archive: $repo${NC}"
        echo "$(date): [DRY RUN] Would ${UNARCHIVE:+un}archive $repo" >> "$LOG"
        return 0
    fi
    if $UNARCHIVE; then
        echo -e "${CYAN}⏪ Unarchiving: $repo...${NC}"
        if gh api -X PATCH "repos/$repo" -f archived=false >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Successfully unarchived: $repo${NC}"
            echo "$(date): Unarchived $repo" >> "$LOG"
        else
            echo -e "${RED}❌ Failed to unarchive: $repo${NC}"
            echo "$(date): Failed to unarchive $repo" >> "$LOG"
        fi
    else
        echo -e "${CYAN}📦 Archiving: $repo...${NC}"
        if gh repo archive "$repo" --yes >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Successfully archived: $repo${NC}"
            echo "$(date): Archived $repo" >> "$LOG"
        else
            echo -e "${RED}❌ Failed to archive: $repo${NC}"
            echo "$(date): Failed to archive $repo" >> "$LOG"
        fi
    fi
}

export -f process_repo
export LOG UNARCHIVE DRY_RUN RED GREEN CYAN YELLOW NC

# --- PARALLEL PROCESSING ---
echo
echo -e "${CYAN}🚀 Processing repositories (${PARALLEL} at a time)...${NC}"
echo

echo "$SELECTED" | xargs -P "$PARALLEL" -I {} bash -c 'process_repo "$@"' _ {}

echo
echo -e "${GREEN}🎉 All done! You can review the log at: ${BOLD}$LOG${NC}"