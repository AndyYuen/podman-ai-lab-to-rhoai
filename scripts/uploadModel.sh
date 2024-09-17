#! /bin/bash

if [ "$#" -ne 2 ]; then
	echo "Usage: $0 sourceFolder targetFolder"
	exit 1
fi

SOURCE_FOLDER=$1
TARGET_FOLDER=$2

source ./s3.env

# upload model
python modelUpload.py $SOURCE_FOLDER $TARGET_FOLDER
