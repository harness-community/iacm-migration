# IaCM Migration Utility
This utility helps create workspace(s) in Harness IaCM and migrates Infrastructure State(s) from local machine to Harness IaCM workspace(s). All workspaces are created inside the same account, organization and project.

## Prerequisites
1. Clone this repo.
2. Install following dependancies:
    * openTofu
    * git
    * [hcledit](https://github.com/minamijoyo/hcledit)
    * perl
3. Generate a Harness [API key](https://developer.harness.io/docs/platform/automation/api/add-and-manage-api-keys/)

### Setup
* Create `.env` file with your Harness account ID and api key, using `.env.example` as an example
* Copies of working directories for each workspace to be migrated should be put under the `./workspaces` directory. Clone your workspace repository(ies) in this folder.
* Fill out the `input.csv` file with the correct values for each workspace. Refer `input.csv` schema section for more details on the fields

### `input.csv` schema
| Name                   | Description                                                                                  | Example Value                                    | Required |
|------------------------|----------------------------------------------------------------------------------------------|--------------------------------------------------|----------|
| workspace_path         | Relative local path to your workspace that was cloned on your local. Path needs to be relative from the folder where you will run the script. | workspaces/verint/env2                           | Yes      |
| workspace_name         | Workspace name to be created in Harness                                                      | env2                                             | Yes      |
| workspace_id           | Workspace ID to be created in Harness                                                        | env2                                             | Yes      |
| org_id                 | Harness Org ID where workspace is to be created                                              | default                                          | Yes      |
| project_id             | Harness Project ID where workspace is to be created                                          | Tushar                                           | Yes      |
| provisioner_type       | `opentofu` or `terraform`                                                                    | opentofu                                         | Yes      |
| provisioner_version    | Version for `provisioner_type` above                                                         | 1.91                                             | Yes      |
| repository             | Your repo URL to be migrated                                                                 | https://github.com/tusharkapadi/verint          | Yes      |
| repository_branch      | Your repo branch to be associated with the workspace                                         | main                                             | Yes      |
| repository_path        | **Should rename to:** `repository_folder_path`<br>Relative path from your repo to your workspace/state to be migrated | env2/                                            | Yes      |
| cost_estimation_enabled| Cost estimation enabled - true or false                                                      | true                                             | Yes       |
| provider_connector_id  | **Should rename to:** `provider_connector`<br>Harness provider connector ID                  | awsoidcconnector                                 | Yes      |
| github_connector_id    | **Should rename to:** `repository_connector`<br>Harness repository connector ID              | tushargithubconnector                           | Yes      |
| tf_variables_json      | Relative path of a json file containing Terraform variables to be created in Harness         | configs/example_workspace/tf_variables.json      | No       |
| env_variables_json     | Relative path of a json file containing Environment variables to be created in Harness       | configs/example_workspace/env_variables.json     | No       |
| tf_variable_files_json | Relative path of a json file containing Terraform variables to be created in Harness         | configs/example_workspace/tf_variables_files.json| No       |


## Usage
To run the migration utility, type `./run.sh input.csv`
