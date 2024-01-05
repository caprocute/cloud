#!/bin/bash

# We need the environment.
ENV=$1

if [ -z "$ENV" ]; then
	echo "usage: db-clone.sh ENV"
	exit 2
fi

# Warning: If you enable set -x then you will leak database passwords.
set -e


echo done