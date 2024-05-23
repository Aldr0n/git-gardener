#!/bin/bash

# Clear the terminal
clear

# Print usage information
usage() {
  echo "Usage: $0 -u <repo-url> -s <source-branch> -t <target-branch> [-d]"
  echo "  -u <repo-url>       : URL of the GitHub repository"
  echo "  -s <source-branch>  : Name of the source branch"
  echo "  -t <target-branch>  : Name of the target branch"
  echo "  -d                  : Delete the source branch after moving files"
  exit 1
}

# Parse arguments
DELETE_OLD_BRANCH=false
while getopts ":u:s:t:d" opt; do
  case ${opt} in
    u )
      REPO_URL=$OPTARG
      ;;
    s )
      SOURCE_BRANCH=$OPTARG
      ;;
    t )
      TARGET_BRANCH=$OPTARG
      ;;
    d )
      DELETE_OLD_BRANCH=true
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
if [ -z "$REPO_URL" ] || [ -z "$SOURCE_BRANCH" ] || [ -z "$TARGET_BRANCH" ]; then
  usage
fi

# Define clone directory
CLONE_DIR="repo-clone"

# Add SSH key to the SSH agent
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
if [ -f "$SSH_KEY_PATH" ]; then
  eval "$(ssh-agent -s)"
  ssh-add $SSH_KEY_PATH
fi

# Clone the repository
git clone $REPO_URL $CLONE_DIR

# Navigate to the cloned repository directory
cd $CLONE_DIR

# Checkout to the source branch
git checkout $SOURCE_BRANCH

# Create and switch to the target branch
git checkout -b $TARGET_BRANCH

# Remove all files in the target branch
git rm -rf .

# Copy all files from the source branch
git checkout $SOURCE_BRANCH -- .

# Add the changes
git add .

# Commit the changes
git commit -m "Moved all files from $SOURCE_BRANCH to $TARGET_BRANCH"

# Push the new branch to the repository
git push origin $TARGET_BRANCH

# Delete the old branch if the flag is set
if [ "$DELETE_OLD_BRANCH" = true ]; then
  DEFAULT_BRANCH=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
  if [ "$SOURCE_BRANCH" = "$DEFAULT_BRANCH" ]; then
    echo "Error: Cannot delete the default branch ($SOURCE_BRANCH)."
    echo "Please change the default branch in the repository settings and rerun the script with the -d flag."
  else
    git push origin --delete $SOURCE_BRANCH
    echo "The old branch $SOURCE_BRANCH has been deleted."
  fi
fi

# Clean up by deleting the local clone directory
cd ..
rm -rf $CLONE_DIR

echo "All files have been moved from $SOURCE_BRANCH to $TARGET_BRANCH in the repository $REPO_URL"
if [ "$DELETE_OLD_BRANCH" = true ]; then
  echo "The old branch $SOURCE_BRANCH has been deleted."
fi
