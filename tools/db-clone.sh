#!/bin/bash

DEPLOY_HOST=$1
SYNC_COPY_TARGET_DBS=$2
DATABASE=$3

echo Arguments: $1 $2 $3

if [ -z "${DEPLOY_HOST}" ]; then
	echo "usage: db-clone.sh DEPLOY_HOST SYNC_COPY_TARGET_DBS DATABASE: DEPLOY_HOST is required"
	exit 2
fi

if [ -z "${SYNC_COPY_TARGET_DBS}" ]; then
	echo "usage: db-clone.sh DEPLOY_HOST SYNC_COPY_TARGET_DBS DATABASE: SYNC_COPY_TARGET_DBS is required"
	exit 2
fi

if [ -z "${DATABASE}" ]; then
	echo "usage: db-clone.sh DEPLOY_HOST SYNC_COPY_TARGET_DBS DATABASE: DATABASE is required"
	exit 2
fi

# Change to script directory.
cd "${0%/*}"
echo `pwd`
whoami

# Name of the archive we're going to make.
STAMP=`date +%Y%m%d_%H%M%S`
FILE=db-${DATABASE}-${STAMP}.sql
echo ${FILE}

# Warning: If you enable set -x then you will leak database passwords.
set -e

# Secure files from gitlab, primarily terraform configuration and SSH key.
if ! [ -f "${TERRAFORM_ENV}" ]; then
    curl --silent "https://gitlab.com/gitlab-org/incubation-engineering/mobile-devops/download-secure-files/-/raw/main/installer" | bash
    TERRAFORM_ENV=`pwd`/.secure_files/prod.json
    SSH_KEY=`pwd`/.secure_files/deploy.pem
    chmod 0600 "${SSH_KEY}"
    ls  -alh
fi

# Warning: If you enable set -x then you will leak database passwords.
if [ "${DATABASE}" == "primary" ]; then
    DATABASE_HOST=`jq -r .database_address.value ${TERRAFORM_ENV}`
    DATABASE_USER=`jq -r .database_username.value ${TERRAFORM_ENV}`
    DATABASE_PASS=`jq -r .database_password.value ${TERRAFORM_ENV}`
    DATABASE_NAME=fk
fi

if [ "${DATABASE}" == "ts" ]; then
    DATABASE_HOST=`jq -r .timescaledb_address.value ${TERRAFORM_ENV}`
    DATABASE_USER=`jq -r .timescaledb_username.value ${TERRAFORM_ENV}`
    DATABASE_PASS=`jq -r .timescaledb_password.value ${TERRAFORM_ENV}`
    DATABASE_NAME=fk
fi
PROXY_URL=postgres://${DATABASE_USER}:${DATABASE_PASS}@127.0.0.1:8432/${DATABASE_NAME}?sslmode=disable

# When we exit, take down our entire process group, specifically the ssh session
# we're opening. I'm planning on redoing how this works.
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# Start tunnel for talking to postgres.
echo Starting tunnel...
TERRAFORM_ENV=${TERRAFORM_ENV} SSH_KEY=${SSH_KEY} DATABASE_HOST=${DATABASE_HOST} ./pg-tunnel.sh &
echo Wait hack...
sleep 5

# Ok, we're ready to start exporting now...
echo Exporting...

if [ "${DATABASE}" = "primary" ]; then
    # Schema first.
    pg_dump --schema-only ${PROXY_URL} > ${FILE}

    # Users table, sanitized of passwords.
    pg_dump --data-only --disable-triggers "${PROXY_URL}" -t fieldkit.user | ./desecreter >> ${FILE}

    # Everything else, exluding heavy and obsolete tables, as well as user which we've already done.
    pg_dump --data-only --disable-triggers "${PROXY_URL}" \
        -T fieldkit.user \
        -T fieldkit.aggregated_24h \
        -T fieldkit.aggregated_12h \
        -T fieldkit.aggregated_6h \
        -T fieldkit.aggregated_1h \
        -T fieldkit.aggregated_30m \
        -T fieldkit.aggregated_10m \
        -T fieldkit.aggregated_1m \
        -T fieldkit.aggregated_10s \
        -T fieldkit.ttn_messages \
        -T fieldkit.bookmarks \
        -T fieldkit.ingestion_queue \
        -T fieldkit.data_record >> ${FILE}
fi

if [ "${DATABASE}" = "ts" ]; then
    echo "SELECT _timescaledb_internal.stop_background_workers();" | psql ${PROXY_URL}

    # Schema first.
    pg_dump --schema-only "${PROXY_URL}" > ${FILE}

    # Everything else.
    pg_dump --data-only --disable-triggers "${PROXY_URL}" >> ${FILE}

    echo "SELECT _timescaledb_internal.start_background_workers();" | psql ${PROXY_URL}
fi

# Compress and send to the sync folder.
ls -alh
echo Compressing...
bzip2 ${FILE}
echo scp ${FILE}.bz2 ${SYNC_COPY_TARGET_DBS}
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ${FILE}.bz2 ${SYNC_COPY_TARGET_DBS}

echo done
