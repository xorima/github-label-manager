# Github-label-manager

This application is designed to manage the labels in your github repository from a source of truth repository.

A good usecase for this is if you want a standardised all your labels across a given repository topic, of `cookbook`, label definitions are collected from `json` files inside the source of truth repository

## User Permissions

- It is recommended to use a github bot account when using this application
- You must ensure the account has permissions to create branches and pull requests directly on the repository, it will not try to fork.
- You must also supply a GITHUB_TOKEN to access the github api server with.

## Items of Note

Github has a rate limiter, do not run this script continously you will get rate limited and then the script will fail

## Configuration

Below are a list of variables, what they mean and example values

| Name | Type | Required | Description |
|------|------|----------|-------------|
| GITHUB_TOKEN | `String` | Yes | Token to access the github api with, see [Creating a token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) |
| GLM_SOURCE_REPO_OWNER | `String` | Yes | The Owner of the repository which holds the desired label definitions |
| GLM_SOURCE_REPO_NAME | `String` | Yes | The name of the repository which holds the desired label definitions |
| GLM_SOURCE_REPO_PATH | `String` | Yes | The folder inside the Source Repo to find the definitions you wish to have applied |
| GLM_DESTINATION_REPO_OWNER | `String` | Yes | The owner of the destination repositories you wish to update |
| GLM_DESTINATION_REPO_TOPICS | `String` | Yes | The topics that the destination repositories are tagged with to search for, Takes a csv, eg: `chef-cookbook,vscode`
| GLM_DELETE_MODE | `Boolean` | Yes | Delete all non-matching labels inside the repository, set to `0` to skip, set to `1` to delete

## Label declaration

Each label must be declared inside a seperate file in the source repository/path combo.

Example file

name: `help-wanted.json`

```json
{
  "name": "help wanted",
  "color": "#008672",
  "description": "Extra attention is needed"
}
```

Examples for all the default label declarations can be found inside `label-definitions` in this repository

## Docker Tags

This application is tagged as follows

| Name | Description |
|------|-------------|
| latest | The latest master merge |
| dev  | The latest Pull Request build |
| semvar (eg: 1.0.0) | A Github Release of a fixed point in time |

While all updates should result in a release this is not always the case, sometimes master will change for non-functional related changes and a release will not be made, eg a new file in the `infrastructure` folder
