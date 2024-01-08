#!/bin/bash

ENV=$1

if [ -z "$ENV" ]; then
	echo "usage: deploy.sh ENV STACK"
	exit 2
fi

STACK=$2

if [ -z "$STACK" ]; then
	echo "usage: deploy.sh ENV STACK"
	exit 2
fi

# Change to script directory.
cd "${0%/*}"
echo `pwd`

# Warning: If you enable set -x then you will leak database passwords.
set -e

# Secure files from gitlab, primarily terraform configuration and SSH key.
if ! [ -f "${TERRAFORM_ENV}" ]; then
    curl --silent "https://gitlab.com/gitlab-org/incubation-engineering/mobile-devops/download-secure-files/-/raw/main/installer" | bash
	TERRAFORM_ENV=`pwd`/.secure_files/${ENV}.json
    SSH_KEY=`pwd`/.secure_files/deploy.pem
    chmod 0600 "${SSH_KEY}"
    ls  -alh
fi

if [ "$ENV" == "prod" ]; then
	export POLL_URL=https://api.fieldkit.org/status
else
	export POLL_URL=https://api.fkdev.org/status
fi

ls -alh

PRIMARY_MIGRATIONS_PATH=~/dev-ops/deploy/primary
TSDB_MIGRATIONS_PATH=~/dev-ops/deploy/tsdb
ARCHIVE=~/dev-ops/deploy/${STACK}.tar

# Warning: If you enable set -x then you will leak database passwords.
# MIGRATE_DATABASE_URL=`jq -r .database_url.value $TERRAFORM_ENV` MIGRATE_PATH=$PRIMARY_MIGRATIONS_PATH ~/dev-ops/deploy/migrate migrate
# MIGRATE_DATABASE_URL=`jq -r .timescaledb_url.value $TERRAFORM_ENV` MIGRATE_PATH=$TSDB_MIGRATIONS_PATH ~/dev-ops/deploy/migrate migrate

./deployer deploy --prepare-only \
 	--cert ${SSH_KEY} \
 	--terraform ${TERRAFORM_ENV} \
 	--archive ${ARCHIVE} \
 	--poll ${POLL_URL}

echo done
