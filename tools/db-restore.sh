#!/bin/bash

if [ -z "${DEPLOY_HOST}" ]; then
	echo "usage: db-clone.sh: DEPLOY_HOST is required"
	exit 2
fi

if [ -z "${SYNC_COPY_TARGET_DBS_PATH}" ]; then
	echo "usage: db-clone.sh: SYNC_COPY_TARGET_DBS_PATH is required"
	exit 2
fi

if [ -z "${DATABASE}" ]; then
	echo "usage: db-clone.sh: DATABASE is required"
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
    TERRAFORM_ENV=`pwd`/.secure_files/dev.json
    SSH_KEY=`pwd`/.secure_files/deploy.pem
    chmod 0600 "${SSH_KEY}"
    ls  -alh
fi

if [ "${DATABASE}" = "primary" ]; then
    ADMIN_URL=`jq -r .database_admin_url.value ${TERRAFORM_ENV}`
    USERNAME=`jq -r .database_username.value ${TERRAFORM_ENV}`
    PASSWORD=`jq -r .database_password.value ${TERRAFORM_ENV}`
    ADDRESS=`jq -r .database_address.value ${TERRAFORM_ENV}`
    TEMPORARY_URL="postgres://${USERNAME}:${PASSWORD}@${ADDRESS}/fk-restore"
fi

if [ "${DATABASE}" = "ts" ]; then
    ADMIN_URL=`jq -r .timescaledb_admin_url.value ${TERRAFORM_ENV}`
    USERNAME=`jq -r .timescaledb_username.value ${TERRAFORM_ENV}`
    PASSWORD=`jq -r .timescaledb_password.value ${TERRAFORM_ENV}`
    ADDRESS=`jq -r .timescaledb_address.value ${TERRAFORM_ENV}`
    TEMPORARY_URL="postgres://${USERNAME}:${PASSWORD}@${ADDRESS}/fk-restore"
fi

echo copying database...

scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ${DEPLOY_HOST}:${SYNC_COPY_TARGET_DBS_PATH}/db-${DATABASE}-latest.xz .

ls -alh

echo importing database...

echo 'CREATE DATABASE "fk-restore"' | psql ${ADMIN_URL}
echo 'ALTER DATABASE "fk-restore" SET search_path TO "\$user", fieldkit, public;' | psql ${ADMIN_URL}

echo 'SET session_replication_role TO replica;' > restore.sql
for a in *.xz; do
    echo $a
    xz -dc $a >> restore.sql
done
echo 'DELETE FROM fieldkit.gue_jobs;' >> restore.sql
echo 'SET session_replication_role TO default;' >> restore.sql

cat restore.sql | psql ${TEMPORARY_URL} < restore.sql

STAMP=`date +%Y%m%d_%H%M%S`
echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'fk';" | psql ${ADMIN_URL}
echo "ALTER DATABASE fk RENAME TO \"fk-${STAMP}\";" | psql ${ADMIN_URL}
echo 'ALTER DATABASE "fk-restore" RENAME TO "fk";' | psql ${ADMIN_URL}
