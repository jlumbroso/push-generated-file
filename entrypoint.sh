#!/bin/sh -l

# Combination of:
# - https://github.com/cpina/github-action-push-to-another-repository
# - https://github.com/dmnemec/copy_file_to_another_repo_action


# Informational prompt
echo "**************************"
echo "PUSH TO REPO GITHUB ACTION"
echo "**************************"
echo ""
echo "Git version: $(git --version)"
echo "SSH version: $(ssh --version)"
echo ""
echo ""


# Work variables
VAR_TARGET_BRANCH_EXISTS=true
VAR_CLONE_DIR="$(mktemp -d)"
VAR_GIT_MODE="https"


echo "<> Start"
echo "<> Processing input parameters"
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

# Determine whether we are in HTTPS or SSH mode
echo "<> Detecting authentication mode"
if [ -z "${INPUT_DESTINATION_REPO}" ]
then
  VAR_GIT_MODE="local"
  echo "No destination repository was provided."
  echo "=> Defaulting to 'local' authentication mode."
else
  if [ ! -z "$INPUT_AUTH_SSH_KEY" ]
  then
    VAR_GIT_MODE="ssh"
    echo "SSH private key detected."
    echo "=> Selecting 'ssh' authentication mode."
  else
    if [ -z "$INPUT_AUTH_GITHUB_TOKEN"]
    then
      VAR_GIT_MODE="local"
      echo "No SSH private key and no GitHub personal access token provided!"
      echo "=> Defaulting to 'local' authentication mode."
    else
      VAR_GIT_MODE="https"
      echo "GitHub Personal Access Token detected."
      echo "=> Selecting 'https' authentication mode."
    fi
  fi
fi


# See https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -e  # exit immediately on error
set -x  # echo all commands


# Configure Git generic
git config --global user.email "$INPUT_AUTHOR_EMAIL"
git config --global user.name "$INPUT_AUTHOR"


# Configuring Git for non-SSH

if [ "${VAR_GIT_MODE}" = "https" ] || [ "${VAR_GIT_MODE}" = "local" ]
then
  # Prevent pushes of big number of files from timing out
  echo "<> Configuring git to avoid hangs when pushing"

  # Switch from HTTP2 -> HTTP1.1
  # See https://stackoverflow.com/a/59474908/408734
  echo "Using HTTP 1.1"
  git config --global http.version HTTP/1.1

  # Change POST buffer chunk size
  # TODO: Set this to largest individual file size as per Atlassian recommendations
  # See https://confluence.atlassian.com/bitbucketserverkb/git-push-fails-fatal-the-remote-end-hung-up-unexpectedly-779171796.html
  echo "Using large POST buffer size"
  git config --global http.postBuffer 157286400
fi

# Configuring SSH settings

if [ "${VAR_GIT_MODE}" = "ssh" ]
then
  echo "<> Configuring SSH settings"

  echo "  * Creating SSH configuration folder"
  mkdir -p ~/.ssh

  echo "  * Storing provided SSH private key"
  echo "$INPUT_AUTH_SSH_KEY" > ~/.ssh/id_key
  chmod u=rw,go= ~/.ssh/id_key

  echo "  * Attempting to generate public SSH key pair"
  ssh-keygen -y -f ~/.ssh/id_key > ~/.ssh/id_key.pub

  echo "  * Public key to be used: $(cat ~/.ssh/id_key.pub)"

  # display visual fingerprint
  ssh-keygen -lvf ~/.ssh/id_key.pub
  
  echo "  * Configuring Git SSH command"
  export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_key -o IdentitiesOnly=yes -o UserKnownHostsFile=~/.ssh/known_hosts -o BatchMode=yes"
  echo "   GIT_SSH_COMMAND='$GIT_SSH_COMMAND'"
  
  # known hosts
  echo "  * Creating local known hosts file"
  touch ~/.ssh/known_hosts
  ssh-keyscan github.com >> ~/.ssh/known_hosts
  ssh-keyscan gitlab.com >> ~/.ssh/known_hosts
  ssh-keyscan bitbucket.com >> ~/.ssh/known_hosts
  cat ~/.ssh/known_hosts
  
  # ssh config to avoid push timeout
  echo "  * Creating SSH config file"
  # See https://bengsfort.github.io/articles/fixing-git-push-pull-timeout/
  # See https://docs.gitlab.com/ee/topics/git/troubleshooting_git.html#check-your-ssh-configuration
  cat > ~/.ssh/config <<EOL
Host *
  ServerAliveInterval 60
  ServerAliveCountMax 5

Host github.com
    Hostname ssh.github.com
    Port 443
EOL
 
  # set local file permissions
  echo "  * Set local file permissions"
  chmod 700 ~/.ssh
  chmod 644 ~/.ssh/config
  chmod 644 ~/.ssh/known_hosts
  chmod 600 ~/.ssh/id_key
  chmod 644 ~/.ssh/id_key.pub
fi


echo "<> Clean up old references maybe"
git remote prune origin


echo "<> Cloning destination git repository"

if [ "$VAR_GIT_MODE" = "local" ]
then
  # git auth: local mode
  echo "  * Using local authentication (no authentication)"

  { # try
    git clone --single-branch --branch "$INPUT_TARGET_BRANCH" "${VAR_CLONE_DIR}"
  } || { # on no such remote branch, pull default branch instead
    echo "  * The input target branch does not already exist on the target repository. It will be created."
    git clone --single-branch "${VAR_CLONE_DIR}"
    VAR_TARGET_BRANCH_EXISTS=false
  }

elif [ "$VAR_GIT_MODE" = "https" ]
then
  # git auth: https mode
  echo "  * Using HTTPS authentication with GitHub personal access token"

  # username/password
  { # try
    git clone --single-branch --branch "$INPUT_TARGET_BRANCH" "https://$INPUT_AUTH_GITHUB_TOKEN@github.com/$INPUT_DESTINATION_REPO.git" "${VAR_CLONE_DIR}"
  } || { # on no such remote branch, pull default branch instead
    echo "  * The input target branch does not already exist on the target repository. It will be created."
    git clone --single-branch "https://$INPUT_AUTH_GITHUB_TOKEN@github.com/$INPUT_DESTINATION_REPO.git" "${VAR_CLONE_DIR}"
    VAR_TARGET_BRANCH_EXISTS=false
  }

elif [ "$VAR_GIT_MODE" = "ssh" ]
then
  # git auth: ssh mode
  echo "  * Using SSH private deploy key"

  { # try
    git clone --single-branch --branch "$INPUT_TARGET_BRANCH" "git@github.com:$INPUT_DESTINATION_REPO.git" "${VAR_CLONE_DIR}"
  } || { # on no such remote branch, pull default branch instead
    echo "  * The input target branch does not already exist on the target repository. It will be created."
    git clone --single-branch "git@github.com:$INPUT_DESTINATION_REPO.git" "${VAR_CLONE_DIR}"
    VAR_TARGET_BRANCH_EXISTS=false
  }

fi

echo "  * Contents of cloned directory at ${VAR_CLONE_DIR}"
ls -la "${VAR_CLONE_DIR}"


echo "Copying files to git repo. Invisible files must be handled differently than visible files."
# Include dot files for source filepath
mkdir -p ${VAR_CLONE_DIR}/$INPUT_DESTINATION_FOLDER

if [ $(find "$INPUT_SOURCE_FILE_PATH" -type f | wc -l) -gt 0 ]; then
  ##cp -r "$INPUT_SOURCE_FILE_PATH"/* "${VAR_CLONE_DIR}/$INPUT_DESTINATION_FOLDER"
  mv "$INPUT_SOURCE_FILE_PATH"/* "${VAR_CLONE_DIR}/$INPUT_DESTINATION_FOLDER"
else
  echo "WARNING: No visible files exist"
fi
invisible_exists=false
if test -f "$INPUT_SOURCE_FILE_PATH"/.??*; then
  ##cp -r "$INPUT_SOURCE_FILE_PATH"/.??* "${VAR_CLONE_DIR}/$INPUT_DESTINATION_FOLDER"
  mv "$INPUT_SOURCE_FILE_PATH"/.??* "${VAR_CLONE_DIR}/$INPUT_DESTINATION_FOLDER"
else
  echo "WARNING: No invisible/hidden (dot) files exist"
fi

cd "${VAR_CLONE_DIR}"
ls -la

# Create branch locally if it doesn't already exist locally
if [ "${VAR_TARGET_BRANCH_EXISTS}" = false ] ; then
  git checkout -b "$INPUT_TARGET_BRANCH"
fi

echo "Adding git commit"

COMMITS_BY_PUSH=2
FILES_BY_COMMIT=50
ADDED=0
COMMIT_ID=0
find . -not -ipath '*.git/*' -type f | while read file
do
  git add "$file" || continue
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
