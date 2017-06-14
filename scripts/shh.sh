#!/bin/bash

function current-env() {
    echo $(gcloud config list core/project --format='value(core.project)' 2>/dev/null)
}

# Usage:
#   scripts/shh.sh -n <secret name> [<category>/<sub category>]
# or:
#   scripts/shh.sh -n <secret name> -a (<category>/<sub category>)
#
# The first one is used to set the secrets for a secret in kubernetes,
# note that it will replace everything in that secret. If you want to
# just add something to a secret you can use `-a (<category>/<sub category>)`
# which will update or add the secrets for that category.
#
# The (<category>/<sub category>) must match the structure in the secrets folder.
#
# Valid arguments are:
#   -n <name> - name of the secret in kubernetes
#   -d - dry run, will only create the manifest but not add it to kubernetes
#   -r <<category>/<sub category>> - update all secrets associated with <<category>/<sub category>>
#   -a <<category>/<sub category>> - to add or update a secret for a category, use together with -n

ENVIRONMENT="$(current-env)"
SECRETS_BASE_PATH="secrets"
SECRET_TEMPLATE_PATH="templates/secrets.yaml"
TMP_PATH="tmp"
TMP_SECRETS="$TMP_PATH/secrets.yaml"
APPS_PATH="_apps/$ENVIRONMENT"

# Modes
FULL="FULL" # create secret with the given (<category>/<sub category>) list
ADD_OR_UPDATE="ADD_OR_UPDATE" # add one (<category>/<sub category>) to a kubernetes secret
RELOAD="RELOAD" # reload all the secrets for a given (<category>/<sub category>s)


# Initial setup, making sure relevant folders exists etc.
function init {
    # call reveal in case some new files have been added by
    # someone else
    git secret reveal -f
    dryRun=false
    mkdir -p $TMP_PATH
}

# Parse the arguments using `getopts`
function parseArgs {
    while getopts ":n:a:dr:" opt; do
        case $opt in
            n)
                secretName=$OPTARG
                mode=$FULL
                ;;
            a)
                credsToAdd=$OPTARG
                mode=$ADD_OR_UPDATE
                ;;
            d)
                dryRun=true
                ;;
            r)
                mode=$RELOAD
                credsToAdd=$OPTARG
                ;;
            \?)
                echo "Invalid option -$OPTARG" >&2
                echo "Usage: shh.sh -n <credential name> [(<category>/<sub category>)]"
                echo "Example: shh.sh -n my-app-secrets a_category_name/s3_credentials another_category_name/s3_credentials"
                exit 1
        esac
    done
    shift $((OPTIND-1))
    paths=($@)

    echo "=> Mode: $mode"
    echo "=> Parsed secret name: $secretName"
    echo "=> Dry run: $dryRun"
}

# Creates category (prefix) for the values from the path, ex. gimbal/s3 -> gimbal.s3
function createCategoryKeyFromPath {
    path=$1
    key="${path/\//-}"
    echo "$key"
}

# Extracts all the secrets from the paths array
function extractSecrets {
    secrets=()
    for path in "${paths[@]}"
    do
        # Remove folders and encrypted secrets
        files=($(ls -p $SECRETS_BASE_PATH/"$path" | grep -v / | grep -v .secret))
        echo "=> Files for $path: ${files[*]}"

        for file in "${files[@]}"
        do
            categoryKey=$(createCategoryKeyFromPath "$path")
            key="$categoryKey.$file"
            value=$(cat $SECRETS_BASE_PATH/"$path"/"$file")
            valueBase64=$(echo -n "$value" | base64)
            entry="$key: $valueBase64"
            secrets+=("$entry")
        done
    done
}

# Moves the manifest template to tmp folder and replace the %NAME% part in the manifest.
function initTemplate {
    echo "=> Initializing template with name: $secretName"
    sed "s;%NAME%;$secretName;g" $SECRET_TEMPLATE_PATH > $TMP_SECRETS
}

# Adds all the secrets from the secrets array to the manifest file
function addSecretsToTemplate {
    for entry in "${secrets[@]}"
    do
        echo "  $entry" >> $TMP_SECRETS
    done
}

# Create or update the secret in kubernetes
function createKubeSecrets {
    kubectl get secrets | grep "^$secretName\s" > /dev/null
    rc=$?; if [ $rc != 0 ]; then
        kubectl create -f $TMP_SECRETS
    else
        kubectl replace -f $TMP_SECRETS
    fi
}

# Reads all the exisiting secret data from kubernetes and keep all
# those that are not to be changed. Those that are to be kept are
# appended to the manifest under construction.
function createManifestFromExistingSecret {
    categoryKey=$(createCategoryKeyFromPath "$credsToAdd")
    initTemplate
    fileReorganized=$(kubectl get secrets "$secretName" -o yaml | perl -0 -p -e "s/.*(data:)(.*)(kind.*)/\2/s")
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [ "$line" = "" ]; then
            continue;
        fi
        if ! [[ "$line" =~ $categoryKey ]]; then
            echo "$line" >> $TMP_SECRETS
        fi
    done <<< "$fileReorganized"
}

function addToLog {
    for path in "${paths[@]}"
    do
        mkdir -p $SECRETS_BASE_PATH/"$path"/"$APPS_PATH"
        touch $SECRETS_BASE_PATH/"$path"/"$APPS_PATH"/"$secretName"
    done
}

function cleanUp {
    if [ $@ != 0 ]; then
        echo "=> Failed to create secrets, manifest saved in: $TMP_SECRETS"
    else
        echo "=> Cleaning up in tmp folder"
        rm $TMP_SECRETS
    fi
}

function createSecrets {
    if [ "$mode" = "$FULL" ]; then
        echo "=> Will create secrets for: ${paths[*]}"
        initTemplate
    else
        echo "=> Will add or update $secretName for $credsToAdd"
        createManifestFromExistingSecret
        paths=($credsToAdd)
    fi
    extractSecrets
    addSecretsToTemplate

    if ! [ $dryRun = true ]; then
        addToLog
        createKubeSecrets
        cleanUp $?
    else
        echo "=> Dry run enabled, only manifest is created"
    fi
}

function getApps {
    path=$1
    apps=($(ls $SECRETS_BASE_PATH/"$path"/"$APPS_PATH"))
}

function reloadSecrets {
    echo "=> Reloading secrets for $credsToAdd"
    getApps "$credsToAdd"
    for secretName in "${apps[@]}"
    do
        createSecrets
    done
}

init
parseArgs "$@"
if [ "$mode" = "$RELOAD" ]; then
    reloadSecrets
else
    createSecrets
fi

find . -name ""$secretName"" | xargs git add
#git commit -m "Added a $APPS_PATH entry"
