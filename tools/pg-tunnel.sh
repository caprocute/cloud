#!/bin/bash

netstat -tupan

if [ -f "${SSH_KEY}" ]; then
	ssh -o "ControlMaster=no" -o StrictHostKeyChecking=no -4 -N -i ${SSH_KEY} -L 8432:${DATABASE_HOST}:5432 ${DEPLOY_HOST}
else
	ssh -o "ControlMaster=no" -o StrictHostKeyChecking=no -4 -N -L 8432:${DATABASE_HOST}:5432 ${DEPLOY_HOST}
fi
