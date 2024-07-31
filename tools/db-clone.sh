#!/bin/bash

if [ -z "${DEPLOY_HOST}" ]; then
	echo "usage: db-clone.sh: DEPLOY_HOST is required"
	exit 2
fi

if [ -z "${SYNC_COPY_TARGET_DBS}" ]; then
	echo "usage: db-clone.sh: SYNC_COPY_TARGET_DBS is required"
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

# Ok, we're ready to start exporting now...
echo exporting...

if [ "${DATABASE}" = "primary" ]; then
    DATABASE_URL=`jq -r .database_url.value ${TERRAFORM_ENV}`

    # Schema first.
    pg_dump --schema-only ${DATABASE_URL} > ${FILE}

    # Users table, sanitized of passwords.
    pg_dump --data-only --disable-triggers "${DATABASE_URL}" -t fieldkit.user | ./desecreter >> ${FILE}

    # Everything else, exluding heavy and obsolete tables, as well as user which we've already done.
    pg_dump --data-only --disable-triggers "${DATABASE_URL}" \
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
    DATABASE_URL=`jq -r .timescaledb_url.value ${TERRAFORM_ENV}`

    echo "SELECT _timescaledb_internal.stop_background_workers();" | psql ${DATABASE_URL}

    # Schema first.
    pg_dump --schema-only "${DATABASE_URL}" > ${FILE}

    # Everything else.
    pg_dump --data-only --disable-triggers "${DATABASE_URL}" >> ${FILE}

    echo "SELECT _timescaledb_internal.start_background_workers();" | psql ${DATABASE_URL}
fi

# Compress and send to the sync folder.
ls -alh
echo compressing...

xz -T2 ${FILE}
ls -alh

scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ${FILE}.xz ${SYNC_COPY_TARGET_DBS}
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${DEPLOY_HOST} ln -sf ${SYNC_COPY_TARGET_DBS_PATH}/${FILE}.xz ${SYNC_COPY_TARGET_DBS_PATH}/db-${DATABASE}-latest.xz

echo done
