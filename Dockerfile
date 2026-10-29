FROM node:24.22.1-bookworm@sha256:d862bb5d082c5ae0210ac07e8c0344cb8cf7bef6d78e9b8c50c179da923108ea AS ui
WORKDIR /build

COPY .git ./.git
COPY Makefile ./Makefile

# download npm dependencies
COPY ui/package-lock.json ./ui/package-lock.json
COPY ui/package.json ./ui/package.json
RUN make npm-install

# build ui
COPY ./ui/ ./ui/
RUN make build-ui

FROM golang:1.27.3-bookworm@sha256:d9b6a1beb9474adc2a1ce842573639b44b2a0dd49b6669f51d3821baf9ec37c9 AS build
WORKDIR /go/src/github.com/pomerium/pomerium

RUN apt-get update \
    && apt-get -y --no-install-recommends install zip

COPY . .
COPY --from=ui /build/ui/dist ./ui/dist

# build
RUN --mount=type=cache,target=/go/pkg/mod make build-go NAME=pomerium
RUN touch /config.yaml

FROM gcr.io/distroless/base-nossl-debian13:debug@sha256:d085c34ea66f46cdd1ff439c01f88c6875f6f49adeb2c1fcc7a22d33e1af515e
ENV AUTOCERT_DIR=/data/autocert
WORKDIR /pomerium
COPY --from=build /go/src/github.com/pomerium/pomerium/bin/* /bin/
COPY --from=build /config.yaml /pomerium/config.yaml
ENTRYPOINT [ "/bin/pomerium" ]
CMD ["--config","/pomerium/config.yaml"]
