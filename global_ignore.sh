#!/bin/bash

# Directory to search for Git repositories
BASE_DIR="$1"

if [ -z "$BASE_DIR" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

# Function to process each Git repository
process_repo() {
  REPO_DIR="$1"
  echo "Processing repository: $REPO_DIR"

  cd "$REPO_DIR" || return

  # Clear the index and reapply the global .gitignore
  git rm -r --cached .
  git add .
  git commit -m "Apply global .gitignore"

  # Reapply global .gitignore configuration
  git config core.excludesfile "$HOME/.gitignore_global"
}

# Export the function for use with find
export -f process_repo

# Find and process all Git repositories
find "$BASE_DIR" -name ".git" -type d -exec bash -c 'process_repo "$(dirname "{}")"' \;

echo "Done!"
