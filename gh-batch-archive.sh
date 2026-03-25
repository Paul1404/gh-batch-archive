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
        echo -e "${RED}Error:${NC} The GitHub CLI ('gh') is required. Please install it from https://cli.github.com/" >&2
        exit 1
    }
}

has_fzf() {
    command -v fzf >/dev/null 2>&1
}

# --- HELPER: require option argument ---
require_arg() {
    if [[ $# -lt 2 || "$2" == --* ]]; then
        echo -e "${RED}Error:${NC} Option '$1' requires an argument." >&2
        exit 1
    fi
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
        --pattern) require_arg "$1" "${2:-}"; PATTERN="$2"; shift 2 ;;
        --interactive) INTERACTIVE=true; shift ;;
        --parallel) require_arg "$1" "${2:-}"; PARALLEL="$2"; shift 2 ;;
        --log) require_arg "$1" "${2:-}"; LOG="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        --*)
            echo -e "${RED}Error:${NC} Unknown option '$1'. Use --help for usage." >&2
            exit 1
            ;;
        *) OWNER="$1"; shift ;;
    esac
done

# --- VALIDATE --parallel IS A POSITIVE INTEGER ---
if ! [[ "$PARALLEL" =~ ^[1-9][0-9]*$ ]]; then
    echo -e "${RED}Error:${NC} --parallel must be a positive integer, got '$PARALLEL'." >&2
    exit 1
fi

require_gh

# --- GET OWNER IF NOT PROVIDED ---
if [[ -z "$OWNER" ]]; then
    OWNER="$(gh api user --jq .login)"
    echo -e "${CYAN}No owner or organization specified. Using your GitHub username: '${OWNER}'.${NC}"
else
    echo -e "${CYAN}Using specified owner/organization: '${OWNER}'.${NC}"
fi

# --- FETCH REPOS ---
# In unarchive mode, list archived repos; in archive mode, list non-archived repos.
if [[ "$UNARCHIVE" == true ]]; then
    echo -e "${CYAN}Searching for archived repositories owned by '${OWNER}'...${NC}"
    REPOS=$(gh repo list "$OWNER" --archived --limit 1000 --json nameWithOwner \
        --jq '.[].nameWithOwner')
else
    echo -e "${CYAN}Searching for non-archived repositories owned by '${OWNER}'...${NC}"
    REPOS=$(gh repo list "$OWNER" --no-archived --limit 1000 --json nameWithOwner \
        --jq '.[].nameWithOwner')
fi

if [[ -z "$REPOS" ]]; then
    if [[ "$UNARCHIVE" == true ]]; then
        echo -e "${YELLOW}No archived repositories found for '${OWNER}'. Nothing to do.${NC}"
    else
        echo -e "${YELLOW}No non-archived repositories found for '${OWNER}'. Nothing to do.${NC}"
    fi
    exit 0
fi

# --- FILTER BY PATTERN ---
if [[ -n "$PATTERN" ]]; then
    echo -e "${CYAN}Filtering repositories by pattern: '${PATTERN}'...${NC}"
    REPOS=$(echo "$REPOS" | grep -E "$PATTERN" || true)
    if [[ -z "$REPOS" ]]; then
        echo -e "${YELLOW}No repositories match the pattern '${PATTERN}'. Exiting.${NC}"
        exit 0
    fi
fi

# --- INTERACTIVE SELECTION ---
select_repos() {
    local repos="$1"
    if has_fzf; then
        echo -e "${CYAN}Interactive selection enabled. Use TAB to select multiple repositories, then press ENTER to confirm your choices.${NC}"
        echo "$repos" | fzf --multi --prompt="Select repos> " --height="$FZF_HEIGHT"
    else
        echo -e "${YELLOW}'fzf' not found. Falling back to a simple numbered menu.${NC}"
        local arr=()
        local i=1
        while IFS= read -r repo; do
            arr+=("$repo")
            echo "  [$i] $repo"
            ((i++))
        done <<< "$repos"
        local total=${#arr[@]}
        echo
        echo -e "${CYAN}Please enter the numbers of the repositories you want to select, separated by spaces (e.g. 1 3 5):${NC}"
        read -r choices
        for n in $choices; do
            if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= total )); then
                echo "${arr[$((n-1))]}"
            else
                echo -e "${YELLOW}Skipping invalid selection: $n${NC}" >&2
            fi
        done
    fi
}

if [[ "$INTERACTIVE" == true ]]; then
    SELECTED="$(select_repos "$REPOS")"
else
    SELECTED="$REPOS"
fi

if [[ -z "$SELECTED" ]]; then
    echo -e "${YELLOW}No repositories selected. Exiting without making any changes.${NC}"
    exit 0
fi

# --- EXPLICIT ACTION SUMMARY ---
if [[ "$UNARCHIVE" == true ]]; then
    ACTION="unarchive"
else
    ACTION="archive"
fi

if [[ "$DRY_RUN" == true ]]; then
    MODE="DRY-RUN (no changes will be made)"
else
    MODE="ACTUAL"
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

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}This is a dry-run. No changes will be made.${NC}"
else
    read -r -p "$(echo -e "${BOLD}Do you want to proceed and ${ACTION} these repositories? [y/N] ${NC}")" CONFIRM
    if ! [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled by user. No changes made.${NC}"
        exit 0
    fi
fi

# --- ARCHIVE/UNARCHIVE FUNCTION ---
# This function is exported for use by xargs subshells.
process_repo() {
    local repo="$1"
    local dry_run="$2"
    local unarchive="$3"
    local log="$4"

    local action_verb="archive"
    if [[ "$unarchive" == true ]]; then
        action_verb="unarchive"
    fi

    if [[ "$dry_run" == true ]]; then
        echo -e "\033[1;33m[DRY RUN] Would ${action_verb}: $repo\033[0m"
        echo "$(date): [DRY RUN] Would ${action_verb} $repo" >> "$log"
        return 0
    fi
    if [[ "$unarchive" == true ]]; then
        echo -e "\033[0;36mUnarchiving: $repo...\033[0m"
        if gh api -X PATCH "repos/$repo" -f archived=false >/dev/null 2>&1; then
            echo -e "\033[0;32mSuccessfully unarchived: $repo\033[0m"
            echo "$(date): Unarchived $repo" >> "$log"
        else
            echo -e "\033[0;31mFailed to unarchive: $repo\033[0m"
            echo "$(date): Failed to unarchive $repo" >> "$log"
            return 1
        fi
    else
        echo -e "\033[0;36mArchiving: $repo...\033[0m"
        if gh repo archive "$repo" --yes >/dev/null 2>&1; then
            echo -e "\033[0;32mSuccessfully archived: $repo\033[0m"
            echo "$(date): Archived $repo" >> "$log"
        else
            echo -e "\033[0;31mFailed to archive: $repo\033[0m"
            echo "$(date): Failed to archive $repo" >> "$log"
            return 1
        fi
    fi
}

export -f process_repo

# --- PARALLEL PROCESSING ---
echo
echo -e "${CYAN}Processing repositories (${PARALLEL} at a time)...${NC}"
echo

# Track failures across parallel execution
FAILURES=0
while IFS= read -r repo; do
    # Wait if we have $PARALLEL background jobs already running
    while (( $(jobs -rp | wc -l) >= PARALLEL )); do
        wait -n 2>/dev/null || FAILURES=$((FAILURES + 1))
    done
    process_repo "$repo" "$DRY_RUN" "$UNARCHIVE" "$LOG" &
done <<< "$SELECTED"

# Wait for remaining background jobs
while (( $(jobs -rp | wc -l) > 0 )); do
    wait -n 2>/dev/null || FAILURES=$((FAILURES + 1))
done

echo
if (( FAILURES > 0 )); then
    echo -e "${YELLOW}Completed with ${FAILURES} failure(s). Review the log at: ${BOLD}$LOG${NC}"
    exit 1
else
    echo -e "${GREEN}All done! You can review the log at: ${BOLD}$LOG${NC}"
fi
