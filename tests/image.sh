#!/usr/bin/env bash
# Smoke tests for the image. Build it first, then:
#
#   docker build -t paseo-web-ui:test .
#   tests/image.sh
#
# Starts the image, then checks what it serves over HTTP.
set -euo pipefail

image=${IMAGE:-paseo-web-ui:test}
name="paseo-web-ui-test-$$"
failures=0

docker run -d --name "$name" -p 127.0.0.1::8080 "$image" >/dev/null
trap 'docker kill "$name" >/dev/null 2>&1 || true; docker container rm "$name" >/dev/null 2>&1 || true' EXIT
port=$(docker port "$name" 8080/tcp | head -1 | sed 's/.*://')
base="http://127.0.0.1:$port"

for _ in $(seq 50); do
    curl -fs -o /dev/null "$base/healthz" && break
    sleep 0.2
done

check() {
    local name=$1 out
    shift
    if out=$("$@" 2>&1); then
        printf 'ok    %s\n' "$name"
    else
        printf 'FAIL  %s\n' "$name"
        printf '%s\n' "$out" | sed 's/^/      /'
        failures=$((failures + 1))
    fi
}

# Prints a response's status line and headers, lowercased.
headers() {
    curl -s -o /dev/null -D - "$@" | tr -d '\r' | tr '[:upper:]' '[:lower:]'
}

export -f headers

# The first JavaScript file index.html loads, e.g. /_expo/static/js/web/index-<hash>.js.
script=$(curl -fs "$base/" | grep -o '/_expo/static/js/web/[^"]*\.js' | head -1)

check "healthz answers" bash -c "[[ \$(curl -fs '$base/healthz') == ok ]]"
check "/ is the Paseo app" bash -c "curl -fs '$base/' | grep -q '<div id=\"root\">'"
check "index.html loads a hashed script" test -n "$script"
check "the script is served" curl -fs -o /dev/null "$base$script"
# Caddy 2.10.2 answered 206 Partial Content for compressed copies, with no
# Range header in the request.
check "compressed copies are a 200, not a 206" bash -c "headers -H 'Accept-Encoding: gzip' '$base$script' | grep -q '^http/1.1 200' && headers -H 'Accept-Encoding: br' '$base/' | grep -q '^http/1.1 200'"
check "brotli copies are served" bash -c "headers -H 'Accept-Encoding: br' '$base$script' | grep -qx 'content-encoding: br'"
check "gzip copies are served" bash -c "headers -H 'Accept-Encoding: gzip' '$base$script' | grep -qx 'content-encoding: gzip'"
check "hashed files are cached for good" bash -c "headers '$base$script' | grep -qx 'cache-control: public, max-age=31536000, immutable'"
check "index.html is revalidated" bash -c "headers '$base/' | grep -qx 'cache-control: no-cache'"
check "app routes get index.html" bash -c "curl -fs '$base/settings/hosts' | grep -q '<div id=\"root\">'"
check "a missing hashed file is a 404" bash -c "headers '$base/_expo/static/js/web/missing.js' | grep -q '^http/1.1 404'"
check "the server isn't named" bash -c "! headers '$base/' | grep -q '^server:'"
check "runs as a non-root user" bash -c "[[ \$(docker exec '$name' id -u) != 0 ]]"
check "Paseo's license is included" docker exec "$name" grep -q 'Apache License' /licenses/paseo/LICENSE

if ((failures)); then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"
