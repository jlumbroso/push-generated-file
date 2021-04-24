#!/bin/sh -l

# Combination of:
# - https://github.com/cpina/github-action-push-to-another-repository
# - https://github.com/dmnemec/copy_file_to_another_repo_action

set -e
set -x

echo "Start"

if [ -z "$INPUT_AUTHOR" ]
then
  INPUT_AUTHOR="$GITHUB_ACTOR"
fi
if [ -z "$INPUT_AUTHOR_EMAIL" ]
then
  INPUT_AUTHOR_EMAIL="$INPUT_AUTHOR@users.noreply.github.com"
fi
if [ -z "$INPUT_TARGET_BRANCH" ]
then
  INPUT_TARGET_BRANCH="main"
fi

TARGET_BRANCH_EXISTS=true

CLONE_DIR=$(mktemp -d)

echo "Git version"
git --version

echo "Using HTTP 1.1"
git config --global http.version HTTP/1.1

echo "Clean up old references maybe"
git remote prune origin

echo "Cloning destination git repository"
# Setup git
git config --global user.email "$INPUT_AUTHOR_EMAIL"
git config --global user.name "$INPUT_AUTHOR"
# Clone branch matching the target branch name or default branch (master, main, etc)
if [ -z "$INPUT_SSH_KEY" ]; then
  # username/password
  { # try
    git clone --single-branch --branch "$INPUT_TARGET_BRANCH" "https://$INPUT_TOKEN@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
  } || { # on no such remote branch, pull default branch instead
    echo "The input target branch does not already exist on the target repository. It will be created."
    git clone --single-branch "https://$INPUT_TOKEN@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
    TARGET_BRANCH_EXISTS=false
  }
else
  # ssh key
  mkdir -p ~/.ssh
  echo "$INPUT_SSH_KEY" > ~/.ssh/id_key
  chmod u=rw,go= ~/.ssh/id_key
  ssh-keygen -y -f ~/.ssh/id_key > ~/.ssh/id_key.pub
  echo "Public key to be used: $(cat ~/.ssh/id_key.pub)"
  
  export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_key -o IdentitiesOnly=yes -o UserKnownHostsFile=~/.ssh/known_hosts -o BatchMode=yes"
  echo "GIT_SSH_COMMAND=$GIT_SSH_COMMAND"
  
  # known hosts
  touch ~/.ssh/known_hosts
  ssh-keyscan github.com >> ~/.ssh/known_hosts
  cat ~/.ssh/known_hosts
  
  # ssh config to avoid push timeout
  # https://bengsfort.github.io/articles/fixing-git-push-pull-timeout/
  # https://docs.gitlab.com/ee/topics/git/troubleshooting_git.html#check-your-ssh-configuration
  cat > ~/.ssh/config <<EOL
Host *
  ServerAliveInterval 60
  ServerAliveCountMax 5

Host github.com
    Hostname ssh.github.com
    Port 443
EOL
 
  # set local file permissions
  chmod 700 ~/.ssh
  chmod 644 ~/.ssh/config
  chmod 644 ~/.ssh/known_hosts
  chmod 600 ~/.ssh/id_key
  chmod 644 ~/.ssh/id_key.pub

  { # try
    git clone --single-branch --branch "$INPUT_TARGET_BRANCH" "git@github.com:$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
  } || { # on no such remote branch, pull default branch instead
    echo "The input target branch does not already exist on the target repository. It will be created."
    git clone --single-branch "git@github.com:$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
    TARGET_BRANCH_EXISTS=false
  }
fi

ls -la "$CLONE_DIR"

echo "Copying files to git repo. Invisible files must be handled differently than visible files."
# Include dot files for source filepath
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER

if [ $(find "$INPUT_SOURCE_FILE_PATH" -type f | wc -l) -gt 0 ]; then
  ##cp -r "$INPUT_SOURCE_FILE_PATH"/* "$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
  mv "$INPUT_SOURCE_FILE_PATH"/* "$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
else
  echo "WARNING: No visible files exist"
fi
invisible_exists=false
if test -f "$INPUT_SOURCE_FILE_PATH"/.??*; then
  ##cp -r "$INPUT_SOURCE_FILE_PATH"/.??* "$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
  mv "$INPUT_SOURCE_FILE_PATH"/.??* "$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
else
  echo "WARNING: No invisible/hidden (dot) files exist"
fi

cd "$CLONE_DIR"
ls -la

# Create branch locally if it doesn't already exist locally
if [ "$TARGET_BRANCH_EXISTS" = false ] ; then
  git checkout -b "$INPUT_TARGET_BRANCH"
fi

echo "Adding git commit"

COMMITS_BY_PUSH=2
FILES_BY_COMMIT=50
ADDED=0
COMMIT_ID=0
find . -type f | while read file
do
  git add "$file"
  ADDED=$((ADDED+1))
  if [ $((ADDED % FILES_BY_COMMIT)) -eq 0 ]
  then
    echo "Attempting a commit (added: ${ADDED}, files_by_commit:${FILES_BY_COMMIT})"
    
    git diff-index --quiet HEAD || git commit --message "Update (${COMMIT_ID}) from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA" && COMMIT_ID=$((COMMIT_ID+1))
  fi
  if [ $((COMMIT_ID % COMMITS_BY_PUSH)) -eq 0 ]
  then
    echo "Attempting a push (commits: ${COMMIT_ID}, commits_by_push:${COMMITS_BY_PUSH})"
    git push origin --set-upstream "$INPUT_TARGET_BRANCH"
  fi
done
#commit remaining
git add .
git status
# git diff-index to avoid an error when there are no changes to commit
git diff-index --quiet HEAD || git commit --message "Update remaining files from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"

##git add .
##git status
# git diff-index to avoid an error when there are no changes to commit
##git diff-index --quiet HEAD || git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"

echo "Pushing git commit. Create branch if none exists."
# --set-upstream also creates the branch if it doesn't already exist in the destination repository
git push origin --set-upstream "$INPUT_TARGET_BRANCH"
