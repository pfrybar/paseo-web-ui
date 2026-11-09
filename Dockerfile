# Paseo's web app, the one app.paseo.sh serves, as a static site.
#
# Paseo publishes the app's build inside its npm package @getpaseo/server, so
# this image takes it from there at PASEO_VERSION. Match that to the Paseo
# version your daemons run.

ARG PASEO_VERSION=0.15.3
ARG CADDY_VERSION=2.11.7

# Runs on the build machine's own architecture: it only downloads and unpacks
# files, which are the same for every platform.
FROM --platform=$BUILDPLATFORM node:24-alpine AS app
ARG PASEO_VERSION
WORKDIR /build
# npm pack checks the tarball against the registry's integrity hash and runs
# none of the package's scripts.
RUN npm pack --silent --ignore-scripts "@getpaseo/server@${PASEO_VERSION}" \
 && tar -xzf "getpaseo-server-${PASEO_VERSION}.tgz" \
 && mv package/dist/server/web-ui /web-ui \
 && test -f /web-ui/index.html
# The package doesn't include Paseo's license, which must go with the app.
ADD https://raw.githubusercontent.com/getpaseo/paseo/v${PASEO_VERSION}/LICENSE /licenses/paseo/LICENSE
# The license readable by all, and Caddy's state directories, owned by the
# user it runs as. Done here so the final stage needs no RUN, and so builds
# for other architectures need no emulation.
RUN chmod -R a+rX /licenses \
 && mkdir -p /caddy/data /caddy/config

FROM caddy:${CADDY_VERSION}-alpine
ARG PASEO_VERSION
LABEL org.opencontainers.image.title="paseo-web-ui" \
      org.opencontainers.image.description="Paseo's web app as a static site" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${PASEO_VERSION}"
COPY --from=app /web-ui /srv
COPY --from=app /licenses /licenses
COPY --from=app --chown=65532:65532 /caddy/data /data
COPY --from=app --chown=65532:65532 /caddy/config /config
COPY Caddyfile /etc/caddy/Caddyfile
ENV PASEO_VERSION=${PASEO_VERSION}
USER 65532:65532
EXPOSE 8080
