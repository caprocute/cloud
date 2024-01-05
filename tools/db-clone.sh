#!/bin/bash

export TERRAFORM_ENV=env.json

# Change to script directory.
cd "${0%/*}"
echo `pwd`

STAMP=`date +%Y%m%d_%H%M%S`
FILE=db-${STAMP}.sql
echo ${FILE}

# Warning: If you enable set -x then you will leak database passwords.
set -e

ls  -alh

# Warning: If you enable set -x then you will leak database passwords.
DATABASE_URL=`jq -r .database_url.value $TERRAFORM_ENV`

echo Exporting...

# Schema first.
docker run --log-driver none --rm postgres pg_dump --schema-only "${DATABASE_URL}" > ${FILE}

# Users table, sanitized of passwords.
docker run --log-driver none --rm postgres pg_dump --data-only --disable-triggers ${extraArgs} "${DATABASE_URL}" \
        -t fieldkit.user | ./desecreter >> ${FILE}

# Everything else, exluding heavy and obsolete tables, as well as user which we've already done.
docker run --log-driver none --rm postgres pg_dump --data-only --disable-triggers ${extraArgs} "${DATABASE_URL}" \
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

# Compress and send to the sync folder.
echo Compressing...
bzip2  ${FILE}
mv ${FILE}.bz2 /svr0/synced/dbs

echo done