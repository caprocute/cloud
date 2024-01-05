#!/bin/bash

export TERRAFORM_ENV=env.json

# We need the environment.
ENV=$1

if [ -z "$ENV" ]; then
	echo "usage: db-clone.sh ENV"
	exit 2
fi

# Change to script directory.
cd "${0%/*}"
echo `pwd`

STAMP=`date +%Y%m%d_%H%M%S`
FILE=db-${ENV}-${STAMP}.sql
echo ${FILE}

# Warning: If you enable set -x then you will leak database passwords.
set -e

# Warning: If you enable set -x then you will leak database passwords.
DATABASE_URL=`jq -r .database_url.value $TERRAFORM_ENV` docker run --log-driver none --rm postgres pg_dump --schema-only "${DATABASE_URL}" > ${FILE}

# docker run --log-driver none --rm postgres pg_dump --data-only --disable-triggers ${extraArgs} '${url}' >> ${FILE}

echo done