#!/bin/bash

set -e
cd $(dirname $0)
log_file=$(pwd)/iacm-migration-$(date "+%Y%m%d%H%M%S").log

csv_file="$1"
git_branch="iacm-migration-$RANDOM"

# Set env variables needed for tofu workspace creation and state migration
export $(cat .env | xargs)

# Set TF password for backend to match HARNESS_PLATFORM_API_KEY already set by env file
export TF_HTTP_PASSWORD="$HARNESS_PLATFORM_API_KEY"

# Create Harness workspaces using CSV
echo "Creating workspace in Harness..."
tofu init 2>&1 >$log_file
tofu apply -var workspace_csv="$csv_file"

# Ask for approval to commit backend updates, and migrate states
echo "-----------------------------------"
echo "The script will do the following: "
echo "Create a git branch $git_branch in each workspace repostory."
echo "Commit changes removing any existing backend configurations, adding a backend pointing to Harness IaCM"
echo "Push this branch upstream, for review/merge."
echo "Migrate state from existing backend, to the workspace in Harness IaCM."
echo "-----------------------------------"
echo -n "Enter \"yes\" to approve: "
read approval
if [ $approval != "yes" ]
then
    exit 1
fi

# Loop through each workspace entry in CSV to initalize workspace
first_loop=true
IFS=$'\n'
for workspace in $(cat $csv_file)
do
    if [ "$first_loop" == true ]; then
        # Skip csv header
        first_loop=false
    else
        tf_path=$(echo $workspace | cut -d',' -f1)
        workspace_id=$(echo $workspace | cut -d',' -f3)
        account_id="$HARNESS_ACCOUNT_ID"
        org_id=$(echo $workspace | cut -d',' -f4)
        project_id=$(echo $workspace | cut -d',' -f5)

        echo "Processing $tf_path"

        last_working_dir=$(pwd)
        cd $tf_path

        tofu init 2>&1 >$log_file

        echo "Removing Backend configuration..."

        for tf in $(ls *.tf)
        do
            # Get 'terraform {backend {..}}'' block
            backend_block=$(cat $tf | hcledit block get terraform.backend)

            # Get cloud block if backend is empty
            if [ -z "$backend_block" ]
            then
                backend_block=$(cat $tf | hcledit block get terraform.cloud)
            fi

            # Only modify files with a terraform backend/cloud block
            if [ ! -z "$backend_block" ]
            then
                # Change spaces in backend block into a regex whitespace match, to handle whitespace getting chomped from hcledit
                regex_noslashes=$(perl -0777 -pe "s#/#\\\/#igs" <(echo -n $backend_block))
                regex=$(perl -0777 -pe "s/\s+/\\\E\\\s*\\\Q/igs" <(echo $regex_noslashes))

                # Remove backend block match via regex (working around hcledit "hcledit block get terraform.backend" working, but not "hcledit block rm terraform.backend")
                perl -0777 -i -pe "s/\Q$regex\E//igs" $tf
            fi
        done

        # Create new backend configuration
        cat >harness-backend.tf <<EOF
terraform {
  backend "http" {
    address = "https://app.harness.io/gateway/iacm/api/orgs/$org_id/projects/$project_id/workspaces/$workspace_id/terraform-backend?accountIdentifier=$account_id"
    username = "harness"
    lock_address = "https://app.harness.io/gateway/iacm/api/orgs/$org_id/projects/$project_id/workspaces/$workspace_id/terraform-backend/lock?accountIdentifier=$account_id"
    lock_method = "POST"
    unlock_address = "https://app.harness.io/gateway/iacm/api/orgs/$org_id/projects/$project_id/workspaces/$workspace_id/terraform-backend/lock?accountIdentifier=$account_id"
    unlock_method = "DELETE"
    }
}
EOF

        # Migrate state
        echo "Migrating state..."
        echo "yes" | tofu init -migrate-state 2>&1 >$log_file

        # commit and push chnages to git
        git checkout $(git show-ref --verify --quiet refs/heads/$git_branch || echo '-b') "$git_branch" 2>&1 >$log_file
        git add harness-backend.tf 2>&1 >$log_file
        git commit -a -m "Remove backend configuration" 2>&1 >$log_file
        git push -u origin "$git_branch" 2>&1 >$log_file

        cd $last_working_dir
    fi
done
