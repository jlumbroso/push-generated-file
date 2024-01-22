# push-generated-file

This GitHub action facilitates pushing a generated file from your workflow to a specified folder in another repository. It's designed for repositories where you have push access and supports various authentication methods.

This action was designed in the context of the [Scarlatti Project](https://github.com/scarlatti/), in which the continuous integration requires pushing 20 GBs of generated files to a repository. The action was designed to handle this volume of files and to be robust, especially when relying on SSH authentication.

## Features

- **High Volume Handling**: Handles large numbers of files and folders without issues (up to several dozen GBs).
- **Multiple Authentication Modes**: Supports GitHub Personal Access Tokens and SSH Private Deploy Keys.
- **Flexible Source and Destination**: Push files from any source path to any destination repository and folder.
- **Branch Management**: Target any branch in the destination repository, with options for new branch creation.
- **Batch Commits and Pushes**: Efficient handling of large numbers of files by grouping them into batches.
- **Invisible Files Handling**: Ensures hidden files (starting with `.`) are also processed.

## Configuration

### Inputs

- `source_file_path`: Path to the generated file or files. Example: `'path/to/file.md'`.
- `destination_repo`: Repository to push the file to. Example: `'some_user/some_repo'`.
- `destination_folder`: Folder to create or use in the destination repository. Example: `'.github/workflows'`.
- `target_branch`: [Optional] Target branch in the destination repository. Defaults to `"main"`.
- `author`: [Optional] Name of the commit's author. Defaults to the user name of the account performing the action.
- `author_email`: [Optional] Email for the commit. Defaults to `author@no-reply...`.
- `auth_github_token`: [Optional] GitHub Personal Access Token for authentication.
- `auth_ssh_key`: [Optional] SSH private key for authentication.
- `files_by_commit`: [Optional] Number of files grouped in a given commit. Default: `"50"`.
- `commits_by_push`: [Optional] Number of commits grouped in each push to the remote. Default: `"2"`.

### Authentication

#### GitHub Personal Access Token

1. Generate a token ([instructions](https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token)).
2. Allow access to "repo" and "workflow".
3. Add the token to your repository's secrets.

#### SSH Private Deploy Key

1. Generate an SSH key pair ([Client side instructions](https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)).
2. Add the public key as a deploy key in the destination repository ([Deploy key repo side instructions](https://docs.github.com/en/developers/overview/managing-deploy-keys#deploy-keys)).
3. Store the private key in your repository's secrets.

### Example Usage

#### Pushing to a Single Directory

```yaml
steps:
  - uses: actions/checkout@v2
  - name: Create output folder and files
    run: sh ./generate_files.sh
  - name: Push files
    uses: your-username/push-generated-file@master
    with:
      auth_github_token: ${{ secrets.GITHUB_TOKEN }}
      source_file_path: 'output'
      destination_repo: 'your-username/destination-repository'
      destination_folder: 'folder/in/repository'
      target_branch: 'feature-branch'
      author: 'your-username'
      author_email: 'your-email@example.com'
```

#### Pushing to Multiple Directories

For pushing different files to multiple directories within the same repository, repeat the push step with different `source_file_path` and `destination_folder` values within the same job.

## TODOs and Future Improvements

- Clean-up and refactor the code for better maintainability.
- Document SSH functionality more comprehensively.
- Implement better defaults for various parameters.
- Add the ability to delete an existing branch ([Reference](https://www.freecodecamp.org/news/how-to-delete-a-git-branch-both-locally-and-remotely/)).
- Explore using `rsync` instead of `mv` for merging folders to avoid issues ([Discussion on merging folders with mv](https://unix.stackexchange.com/questions/127712/merging-folders-with-mv/127715)).
- Consider recommendations for handling HTTP problems, such as protocol and buffer size adjustments ([Related Stack Overflow discussion](https://stackoverflow.com/questions/59282476/error-rpc-failed-curl-92-http-2-stream-0-was-not-closed-cleanly-protocol-erro)).
- Emphasize that the main motivation for SSH is more robust I/O.
- Create a tutorial for adding deploy keys, including generation, upload to the repository, and specification in parameters.

## Ideas

- Explore and document the nuances of HTTP vs. SSH in terms of performance and reliability.
- Provide guidelines or a troubleshooting section for common issues encountered during file pushing.

## Contributing

Contributions, issues, and feature requests are welcome. Feel free to check[issues page if you want to contribute.

## License

This project is licensed under MIT License.