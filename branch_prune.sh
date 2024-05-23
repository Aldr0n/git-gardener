#!/bin/bash

# Clear the terminal
clear

# Initialize counters and arrays
REPO_COUNT=0
ABANDONED_BRANCH_COUNT=0
REPOS=()
BRANCHES=()

# Function to display usage information
usage() {
  echo "Usage: $0 [-p <path>]"
  echo "  -p <path> : Specify the path to search for GitHub repositories (default is current directory)"
  exit 1
}

# Parse arguments
SEARCH_PATH="."
while getopts ":p:" opt; do
  case ${opt} in
    p )
      SEARCH_PATH=$OPTARG
      ;;
    \? )
      usage
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND -1))

# Add SSH key to the SSH agent
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
if [ -f "$SSH_KEY_PATH" ]; then
  eval "$(ssh-agent -s)"
  ssh-add $SSH_KEY_PATH
fi

# Function to prune and delete local branches not present on the remote
prune_and_delete_local_branches() {
  local REPO_PATH=$1
  local REPO_NAME=$(basename $REPO_PATH)
  cd $REPO_PATH

  # Fetch remote changes and prune deleted branches
  git fetch --all --prune

  # Get the list of local branches
  LOCAL_BRANCHES=$(git branch --format='%(refname:short)')

  # Get the list of remote branches
  REMOTE_BRANCHES=$(git branch -r --format='%(refname:short)' | sed 's/origin\///')

  # Initialize branch count for this repository
  LOCAL_ABANDONED_BRANCH_COUNT=0
  LOCAL_DELETED_BRANCHES=""

  # Delete local branches not present on the remote
  for BRANCH in $LOCAL_BRANCHES; do
    if ! echo "$REMOTE_BRANCHES" | grep -q "^$BRANCH$"; then
      echo "Deleting local branch: $BRANCH from repository: $REPO_NAME"
      git branch -D $BRANCH
      ABANDONED_BRANCH_COUNT=$((ABANDONED_BRANCH_COUNT + 1))
      LOCAL_ABANDONED_BRANCH_COUNT=$((LOCAL_ABANDONED_BRANCH_COUNT + 1))
      LOCAL_DELETED_BRANCHES="$LOCAL_DELETED_BRANCHES $BRANCH"
    fi
  done

  # If no branches were deleted, add an entry indicating that
  if [ $LOCAL_ABANDONED_BRANCH_COUNT -eq 0 ]; then
    LOCAL_DELETED_BRANCHES="None"
  fi

  REPOS+=("$REPO_NAME")
  BRANCHES+=("$LOCAL_DELETED_BRANCHES")

  # Return to the original directory
  cd - > /dev/null
}

# Function to find GitHub repositories and prune and delete local branches
find_and_process_repos() {
  local DIR=$1

  for ITEM in "$DIR"/*; do
    if [ -d "$ITEM" ]; then
      if [ -d "$ITEM/.git" ]; then
        echo "Processing repository: $ITEM"
        REPO_COUNT=$((REPO_COUNT + 1))
        prune_and_delete_local_branches "$ITEM"
      else
        find_and_process_repos "$ITEM"
      fi
    fi
  done
}

# Start processing from the specified directory
find_and_process_repos "$SEARCH_PATH"

# Display statistics
echo "Completed processing all repositories."
echo "Total repositories found: $REPO_COUNT"
echo "Total abandoned branches deleted: $ABANDONED_BRANCH_COUNT"
echo

# Display table
printf "%-30s | %-30s\n" "Repository" "Deleted Branches"
printf "%-30s | %-30s\n" "------------------------------" "------------------------------"
for ((i=0; i<${#REPOS[@]}; i++)); do
  printf "%-30s | %-30s\n" "${REPOS[$i]}" "${BRANCHES[$i]}"
done
