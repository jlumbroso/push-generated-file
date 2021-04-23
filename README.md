# push-generated-file

A github action. Generate a file in your action then use this action to push it to a folder in another repository. You have to have permssion to push to that repository.

TODO:
- clean-up
- document SSH functionality
- better defaults
- ability to delete existing branch
- https://www.freecodecamp.org/news/how-to-delete-a-git-branch-both-locally-and-remotely/
- also see: https://github.com/rayluo/github-pages-overwriter/blob/dev/action.yml
- use `rsync` instead of `mv` if branch exists to avoid problem when merging folders
- https://unix.stackexchange.com/questions/127712/merging-folders-with-mv/127715

Ideas:
- have recommendations about HTTP problems? with protocol and/or buffer size?
- https://stackoverflow.com/questions/59282476/error-rpc-failed-curl-92-http-2-stream-0-was-not-closed-cleanly-protocol-erro
- describe that main motivation for SSH is more robust I/O?
- tutorial to add deploy keys (generation, upload to repo as deploy key, upload to account or organization as secret, specify in parameters)

## Original work
- Forked from https://github.com/cpina/github-action-push-to-another-repository which, at the time, deleted the files in a target repository, then pushed a generated file into that blank repository.
- Edits were made based on https://github.com/dmnemec/copy_file_to_another_repo_action which, at the time, pushed a copy of an already existing file to a directory in a target repository.

## Inputs
### `source_file_path`
Path to your generated file or to multiple files. **Example: `'path/to/file.md'`**. I think it doesn't have to be in a folder. Maybe a file that already exists in your current repo would work too, but I haven't tried that yet.

### `destination_repo`
Repository to push file to. **Example: `'some_user/some_repo'`**

### `destination_folder`
Folder to create or use in destination repository. It can be a set of nested folders. **Example: `'.github/workflows'`**

### `target_branch`
[Optional] A branch in the destination repository. **Default is "main"**. I think the branch needs to already exist, but I'm not sure.

### `author`
[Optional] Name of the commit's author. **Default is user name of account doing the pushing**.

### `author_email`
[Optional] Email for the commit. **Default is `author@no-reply...`**

### `token`
Token/Secret that lets your repo push to a repo on which you have permissions. **Example: ${{ secrets.PUSH_FILE_TOKEN }}`**

Generate your personal token ([github instructions](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token)):
1. Go to https://github.com/settings/tokens
1. Generate a new token
1. Choose to allow access to "repo"
1. Choose to allow access to "workflow"
1. Copy the token

Make the token available to the Github Action:
1. Go to the repository you will push from
1. Tap the 'Settings' tab
1. Tap 'Secrets' in the column on the left
1. Tap "Add a new secret"
1. Give it a name that will help you remember what it's for, like "PUSH_FILE_TOKEN"

## Example usage with one directory to push to
```yaml
    steps:
      - uses: actions/checkout@v2
      - name: Create output folder and files
        run:  sh ./generate_files.sh
      - name: Push files
        uses: plocket/push-generated-file@master
        with:
          token: ${{ secrets.PUSH_FILE_TOKEN }}
          source_file_path: 'output'
          destination_repo: 'plocket/some-destination-repository'
          destination_folder: 'folder/in/repository'
          target_branch: 'feature-branch'
          author: 'plocket'
          author_email: 'plocket@example.com'
```

## Example usage with two directories to push to
If you want to push different files to two different directories in the **same repository**, repeat the above in a new run IN THE SAME JOB.

DO NOT try to create separate `job`s for each destination folder you want to push to. Jobs happen at the same time as each other and they will try to push on top of the same commit sometimes. That is, one job will make a push and change the destination repo hash then the next job will try to make a push to the old hash and it will fail. `run`s happen sequentially and that makes sure each push builds on the last one correctly.

```yaml
    steps:
      - uses: actions/checkout@v2
      - name: Create 1st output folder and files
        run:  sh ./generate_files.sh
      - name: Push files
        uses: plocket/push-generated-file@master
        with:
          token: ${{ secrets.PUSH_FILE_TOKEN }}
          source_file_path: 'first_output_directory'
          destination_repo: 'plocket/some-destination-repository'
          destination_folder: 'folder/in/repository'
          target_branch: 'feature-branch'
          author: 'plocket'
          author_email: 'plocket@example.com'
          
      - name: Create 2nd output folder and files
        run:  sh ./generate_other_files.sh
      - name: Push the same or different files
        uses: plocket/push-generated-file@master
        with:
          token: ${{ secrets.PUSH_FILE_TOKEN }}
          # You need a different output folder so that all the
          # previous files don't build up in one folder and get
          # pushed to every destination folder
          source_file_path: 'second_output_directory'
          destination_repo: 'plocket/some-destination-repository'
          destination_folder: 'other/destination_folder'
          target_branch: 'feature-branch'
          author: 'plocket'
          author_email: 'plocket@example.com'
```

<!-- Working example dealing with multiple files and nested folders: https://github.com/plocket/source_repo/blob/main/.github/workflows/push_multiple_files.yml

Repo it pushes to: https://github.com/plocket/destination_repo -->
