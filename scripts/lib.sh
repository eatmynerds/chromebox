export NIX_CONFIG="extra-experimental-features = nix-command flakes${NIX_CONFIG:+
$NIX_CONFIG}"

check_secrets_untracked() {
  local tracked
  tracked=$(git ls-files -- .env 'secrets/*' '*.iso' 2>/dev/null || true)
  if [ -n "$tracked" ]; then
    echo "error: these secret files are tracked by git and would be pushed:" >&2
    echo "$tracked" >&2
    echo "fix: git rm --cached $tracked" >&2
    exit 1
  fi
}

require_env() {
  if [ ! -f .env ]; then
    echo "error: no .env -- run: cp env.example .env  and add your public key" >&2
    exit 1
  fi
}

env_value() {
  sed -e 's/\r$//' .env \
    | sed -nE "s/^[[:space:]]*(export[[:space:]]+)?$1[[:space:]]*=[[:space:]]*//p" \
    | tail -n 1 \
    | sed -E "s/^\"(.*)\"$/\1/; s/^'(.*)'$/\1/"
}

build_authorized_keys() {
  local out=$1
  require_env
  sed -e 's/\r$//' .env \
    | sed -nE 's/^[[:space:]]*(export[[:space:]]+)?SSH_PUBLIC_KEY[A-Za-z0-9_]*[[:space:]]*=[[:space:]]*//p' \
    | sed -E "s/^\"(.*)\"$/\1/; s/^'(.*)'$/\1/" \
    | grep -v '^[[:space:]]*$' > "$out" || true
  if [ ! -s "$out" ]; then
    echo "error: no SSH_PUBLIC_KEY in .env -- refusing to continue, you'd be locked out" >&2
    exit 1
  fi
  if grep -q REPLACE_ME "$out"; then
    echo "error: .env still has the example key -- put your real public key in SSH_PUBLIC_KEY" >&2
    exit 1
  fi
}

build_password_hash() {
  local out=$1 pw
  require_env
  pw=$(env_value USER_PASSWORD)
  [ -n "$pw" ] || return 0
  printf '%s' "$pw" | openssl passwd -6 -stdin > "$out"
}

build_portainer_password() {
  local out=$1 pw
  require_env
  pw=$(env_value PORTAINER_ADMIN_PASSWORD)
  [ -n "$pw" ] || return 0
  if [ "${#pw}" -lt 12 ]; then
    echo "error: PORTAINER_ADMIN_PASSWORD must be at least 12 characters (Portainer's rule)" >&2
    exit 1
  fi
  printf '%s' "$pw" > "$out"
}

ensure_token() {
  mkdir -p secrets
  if [ ! -f secrets/k3s-token ]; then
    head -c 32 /dev/urandom | base64 | tr -d '/+=' > secrets/k3s-token
    chmod 600 secrets/k3s-token
  fi
}
