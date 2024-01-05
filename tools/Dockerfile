FROM rust:latest AS rust-tools
WORKDIR /work
RUN git clone https://github.com/conservify/dev-ops.git
RUN cd dev-ops && make rust-binaries
RUN pwd

FROM ruby:3.1
WORKDIR /work
COPY db-clone.sh .
COPY --from=rust-tools /work/dev-ops/build/desecreter .
COPY --from=rust-tools /work/dev-ops/build/deployer .
RUN ls -alh

ARG DEPLOY_HOST
ARG CI_JOB_TOKEN
ARG CI_PROJECT_ID

ENV DEPLOY_HOST=$DEPLOY_HOST
ENV CI_JOB_TOKEN=$CI_JOB_TOKEN
ENV CI_PROJECT_ID=$CI_PROJECT_ID

RUN curl --silent "https://gitlab.com/gitlab-org/incubation-engineering/mobile-devops/download-secure-files/-/raw/main/installer" | bash

RUN chmod 0600 .secure_files/deploy.pem
RUN ssh -i .secure_files/deploy.pem -o StrictHostKeyChecking=no ${DEPLOY_HOST} "rm -rf working/db-clone && mkdir -p working/db-clone"
RUN scp -i .secure_files/deploy.pem -o StrictHostKeyChecking=no -r .secure_files/prod.json "${DEPLOY_HOST}:working/db-clone/env.json"
RUN scp -i .secure_files/deploy.pem -o StrictHostKeyChecking=no -r db-clone.sh "${DEPLOY_HOST}:working/db-clone"
RUN scp -i .secure_files/deploy.pem -o StrictHostKeyChecking=no -r desecreter "${DEPLOY_HOST}:working/db-clone"
RUN ssh -i .secure_files/deploy.pem -o StrictHostKeyChecking=no ${DEPLOY_HOST} working/db-clone/db-clone.sh
