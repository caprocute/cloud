FROM rust:latest AS rust-tools
WORKDIR /work
RUN git clone https://github.com/conservify/dev-ops.git
RUN cd dev-ops && make rust-binaries
RUN pwd

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl postgresql-client ruby jq openssh-client net-tools bzip2 xz-utils
WORKDIR /work
COPY db-clone.sh .
COPY pg-tunnel.sh .
COPY --from=rust-tools /work/dev-ops/build/desecreter .
COPY --from=rust-tools /work/dev-ops/build/deployer .
RUN ls -alh
RUN pwd