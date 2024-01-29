#!/usr/bin/env bash

set -e

# Install jq if not already installed
if ! command -v jq &> /dev/null; then
    sudo apt-get update
    sudo apt-get install jq
fi

JSON_FILE="recons/${PIPELINE_NAME}/metrics.json"
NIFTI_FILE="recons/${PIPELINE_NAME}/${PIPELINE_NAME}.nii.gz"
README_FILE="README.md"

DIRNAME=$(dirname "${NIFTI_FILE}")
BASENAME=$(basename "${NIFTI_FILE}")
cp "${DIRNAME}/${BASENAME}" "${BASENAME}"

echo "[DEBUG] Checking file..."
ls ${BASENAME} -lahtr

# Upload to Nectar Swift Object Storage
URL=https://object-store.rc.nectar.org.au:8888/v1/AUTH_dead991e1fa847e3afcca2d3a7041f5d/qsmxt/${BASENAME}
#if curl --output /dev/null --silent --head --fail "${URL}"; then
if false; then
    echo "[DEBUG] ${BASENAME} exists in nectar swift object storage"
else
    echo "[DEBUG] ${BASENAME} does not exist yet in nectar swift - uploading it there as well!"

    if [ -n "$swift_setup_done" ]; then
        echo "[DEBUG] Setup already done. Skipping."
    else
        echo "[DEBUG] Configure for SWIFT storage"
        sudo pip3 install setuptools
        sudo pip3 install wheel
        sudo pip3 install python-swiftclient python-keystoneclient
        export OS_AUTH_URL=https://keystone.rc.nectar.org.au:5000/v3/
        export OS_AUTH_TYPE=v3applicationcredential
        export OS_PROJECT_NAME="neurodesk"
        export OS_USER_DOMAIN_NAME="Default"
        export OS_REGION_NAME="Melbourne"

        export swift_setup_done="true"
    fi

    echo "[DEBUG] Uploading via swift..."
    # swift upload qsmxt "${BASENAME}" --segment-size 1073741824 --verbose 
    # SWIFTCLIENT IS BROKEN ON UBUNTU 22.04 in version


    # THIS ALSO DOESN'T WORK and fails with TLSv1.3 (OUT), TLS alert, decode error (562)
    # curl -i \
    # -H "Content-Type: application/json" \
    # -d '
    # { "auth": {
    # "identity": {
    #     "methods": ["application_credential"],
    #     "application_credential": {
    #     "id": "'"$OS_APPLICATION_CREDENTIAL_ID"'",
    #     "secret": "'"$OS_APPLICATION_CREDENTIAL_SECRET"'"
    #     }
    # }
    # }
    # }' $OS_AUTH_URL/auth/tokens > token.txt

    # X_AUTH_TOKEN=`grep X-Subject-Token token.txt | awk '{printf $2}' | awk '{ gsub (" ", "", $0); print}'`

    # X_AUTH_TOKEN=${X_AUTH_TOKEN//[$'\t\r\n']} #Token needs to be cleaned up!


    # # upload file:
    # curl -i -T "${BASENAME}" -X PUT -H "X-Auth-Token: $X_AUTH_TOKEN" https://object-store.rc.nectar.org.au/v1/AUTH_dead991e1fa847e3afcca2d3a7041f5d/qsmxt/

    sudo apt install rclone
    mkdir -p ~/.config/rclone/
    echo "[nectar-swift]
            type = swift
            env_auth = true" >  ~/.config/rclone/rclone.conf

    cat ~/.config/rclone/rclone.conf

    rclone copy "${BASENAME}" nectar-swift:qsmxt

    # Check if it is uploaded to Nectar Swift Object Storage and if so, add it to the database
    if curl --output /dev/null --silent --head --fail "${URL}"; then
        echo "[DEBUG] ${BASENAME} exists in nectar swift object storage"

        curl -X POST \
        -H "X-Parse-Application-Id: ${PARSE_APPLICATION_ID}" \
        -H "X-Parse-REST-API-Key: ${PARSE_REST_API_KEY}" \
        -H "X-Parse-Master-Key: ${PARSE_MASTER_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"url\":\"$URL\",
            \"RMSE\": $(jq '.RMSE' "$JSON_FILE"),
            \"NRMSE\": $(jq '.NRMSE' "$JSON_FILE"),
            \"HFEN\": $(jq '.HFEN' "$JSON_FILE"),
            \"MAD\": $(jq '.MAD' "$JSON_FILE"),
            \"XSIM\": $(jq '.XSIM' "$JSON_FILE"),
            \"CC1\": $(jq '.CC[0]' "$JSON_FILE"),
            \"CC2\": $(jq '.CC[1]' "$JSON_FILE"),
            \"NMI\": $(jq '.NMI' "$JSON_FILE"),
            \"GXE\": $(jq '.GXE' "$JSON_FILE")
        }" \
        https://parseapi.back4app.com/classes/Images

    else
        echo "[DEBUG] ${BASENAME} does not exist yet in nectar swift"
        exit 2
    fi
fi

# Values to append to the next row
new_values=("$PIPELINE_NAME" $(jq '.HFEN' "$JSON_FILE") $(jq '.NMI' "$JSON_FILE") $(jq '.RMSE' "$JSON_FILE") $(jq '.MAD' "$JSON_FILE") $(jq '.CC[0]' "$JSON_FILE") $(jq '.CC[1]' "$JSON_FILE") $(jq '.GXE' "$JSON_FILE") $(jq '.NRMSE' "$JSON_FILE") $(jq '.XSIM' "$JSON_FILE"))

# Read the content of the file
file_content=$(cat "$README_FILE")

# Find the position of the last row in the table
last_row_start=$(echo "$file_content" | grep -n '| ---' | tail -n 1 | cut -d ':' -f 1)
last_row_end=$((last_row_start + 1))

# Create a string with the new values
new_row=$(IFS='|'; echo "| ${new_values[*]} |")

# Insert the new row after the last row in the table
updated_content=$(echo "$file_content" | sed "${last_row_end}a $new_row")

# Write the updated content back to the file
echo "$updated_content" > "$README_FILE"