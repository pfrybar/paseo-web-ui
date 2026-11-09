# AGENTS.md

A container image that serves Paseo's web app, the one app.paseo.sh serves, as
a static site (`ghcr.io/pfrybar/paseo-web-ui`). `README.md` is for people
using the image.

## Layout

- `Dockerfile`: takes the app's build from the npm package
  `@getpaseo/server` at `PASEO_VERSION`, and serves it with Caddy.
- `Caddyfile`: port 8080, caching, compression, the app's fallback to
  `index.html`, and `/healthz`.
- `tests/image.sh`: smoke tests for the built image.
- `.github/workflows/ci.yml`: lints, builds for amd64 and arm64, tests, and
  publishes to GHCR from `main` only.

## Build and test

```sh
docker build -t paseo-web-ui:test .
tests/image.sh
docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:v0.10.0 tests/image.sh
docker run --rm -v "$PWD/Caddyfile:/Caddyfile:ro" caddy:2.11.7-alpine caddy fmt --diff /Caddyfile
```

Add a check to `tests/image.sh` for new behavior.

## Rules

- Keep `PASEO_VERSION` in step with the Paseo version the daemons run, such as
  the workbench image's.
- The final stage has no `RUN`, so builds for other architectures need no
  emulation. Do that work in the `app` stage.
- The image runs as a non-root user and serves plain HTTP on 8080; TLS is the
  ingress's job.
- Paseo's license must stay in the image (`/licenses/paseo/LICENSE`).

## Commits and pull requests

- Commit on a branch, never `main`. Explain why in the body, not just what.
- End the message with a `Co-Authored-By` trailer naming the agent and model.
- Commits are SSH-signed. If signing fails, stop and report it; don't use
  `--no-gpg-sign`.
- You can't push to `origin`. Push to your account's fork and open a pull
  request; the maintainer reviews and merges it:

  ```sh
  gh repo fork --remote --remote-name fork      # once per clone
  gh repo set-default pfrybar/paseo-web-ui      # once per clone
  git push -u fork HEAD
  gh pr create --fill
  ```
