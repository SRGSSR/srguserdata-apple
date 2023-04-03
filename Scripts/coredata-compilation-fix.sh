#!/bin/bash

# This script attempts to apply write permission on XC mapping files, to avoid MappingModelCompile errors.
# It should be applied as a pre action of a target build. 

REPOSITORY_FOLDER=$1

echo "SRGUserData: pre action started."

if [[ -z "${REPOSITORY_FOLDER}" ]]; then
    echo "SRGUserData: a repository folder must be provided."
    exit 1
fi

# Get SRGUserData CoreData checkout path.
SRG_USER_DATA_DATA="${REPOSITORY_FOLDER}/Sources/SRGUserData/Data"

if [[ -z "${SRG_USER_DATA_DATA}" ]]; then
    echo "SRGUserData: warning, SRGUserData Data folder does not exist."
    exit 0
fi

find "$SRG_USER_DATA_DATA" -type d -name "*.xcmappingmodel" -exec chmod +w {}/xcmapping.xml \;
echo "SRGUserData: the xcmapping.xml files have write permission now."