#!/bin/bash

# Clear the terminal
clear

# Print usage information
usage() {
  echo "Usage: $0 -p <path> [-g <global-gitignore>]"
  echo "  -p <path>             : Path to the directory where the global .gitignore should be enforced"
  echo "  -g <global-gitignore> : (Optional) Path to the global .gitignore file (default is ~/.gitignore_global)"
  exit 1
}

# Parse arguments
GLOBAL_GITIGNORE="$HOME/.gitignore_global"
while getopts ":g:p:" opt; do
  case ${opt} in
    g )
      GLOBAL_GITIGNORE=$OPTARG
      ;;
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

# Check required arguments
if [ -z "$SEARCH_PATH" ]; then
  usage
fi

# Function to enforce the global .gitignore
enforce_gitignore() {
  local REPO_PATH=$1
  local REPO_NAME=$(basename $REPO_PATH)
  cd $REPO_PATH

  # Copy the global .gitignore to the repository
  cp $GLOBAL_GITIGNORE .gitignore

  # List of removed files
  REMOVED_FILES=$(git ls-files -o -i --exclude-standard)

  # Add and commit the global .gitignore
  git add .gitignore
  git commit -m "Enforce global .gitignore"

  # Remove files matching the .gitignore from the index
  git rm -r --cached .

  # Add remaining files
  git add .

  # Commit the changes
  git commit -m "Remove ignored files from index"

  # Push changes to the remote repository
  git push origin $(git rev-parse --abbrev-ref HEAD)

  # Store the results
  echo "Repository: $REPO_NAME" >> $REPORT_FILE
  if [ -n "$REMOVED_FILES" ]; then
    echo "Removed files:" >> $REPORT_FILE
    echo "$REMOVED_FILES" | while read -r FILE; do
      echo "  - $FILE" >> $REPORT_FILE
    done
  else
    echo "No files removed." >> $REPORT_FILE
  fi
  echo "" >> $REPORT_FILE

  # Return to the original directory
  cd - > /dev/null
}

# Function to find GitHub repositories and enforce the global .gitignore
find_and_process_repos() {
  local DIR=$1

  for ITEM in "$DIR"/*; do
    if [ -d "$ITEM" ]; then
      if [ -d "$ITEM/.git" ]; then
        echo "Processing repository: $ITEM"
        enforce_gitignore "$ITEM"
      else
        find_and_process_repos "$ITEM"
      fi
    fi
  done
}

# Report file
REPORT_FILE="gitweeder_report.txt"
echo "GitWeeder Report" > $REPORT_FILE
echo "================" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Start processing from the specified directory
find_and_process_repos "$SEARCH_PATH"

echo "Global .gitignore has been enforced in all repositories under $SEARCH_PATH"
echo "Report saved to $REPORT_FILE"
