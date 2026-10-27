#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="${1:-$repo_dir/scripts/xlion-repo-rpm-sign-packages}"
tmp_dir="$(mktemp -d /tmp/xlion-rpm-sign-test.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

bin_dir="$tmp_dir/bin"
rpm_dir="$tmp_dir/rpms"
mkdir -p "$bin_dir" "$rpm_dir"
printf 'fixture\n' > "$rpm_dir/test.rpm"

cat > "$bin_dir/rpmsign" <<'MOCK'
#!/bin/bash
count=0
[[ -f "$MOCK_SIGN_COUNT" ]] && read -r count < "$MOCK_SIGN_COUNT"
count=$((count + 1))
printf '%s\n' "$count" > "$MOCK_SIGN_COUNT"
printf '%s\n' "$@" > "$MOCK_SIGN_ARGS.$count"
if (( count > 1 )) && [[ ${RETRY_SIGN_RC:-0} != 0 ]]; then
  exit "$RETRY_SIGN_RC"
fi
exit 0
MOCK

cat > "$bin_dir/rpmkeys" <<'MOCK'
#!/bin/bash
count=0
[[ -f "$MOCK_VERIFY_COUNT" ]] && read -r count < "$MOCK_VERIFY_COUNT"
count=$((count + 1))
printf '%s\n' "$count" > "$MOCK_VERIFY_COUNT"
if (( count > 1 )) && [[ -n ${RETRY_OUTPUT:-} ]]; then
  printf '%s\n' "$RETRY_OUTPUT"
else
  printf '%s\n' "$RPMKEYS_OUTPUT"
fi
exit "${RPMKEYS_RC:-0}"
MOCK

cat > "$bin_dir/sq" <<'MOCK'
#!/bin/bash
exit 0
MOCK
chmod +x "$bin_dir"/*

export PATH="$bin_dir:$PATH"
export MOCK_SIGN_COUNT="$tmp_dir/sign.count"
export MOCK_SIGN_ARGS="$tmp_dir/sign.args"
export MOCK_VERIFY_COUNT="$tmp_dir/verify.count"
export GPG_KEY=0123456789ABCDEF0123456789ABCDEF01234567
v6_fingerprint=1122334455667788AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFEDCBA9876543210

fingerprint_line="/tmp/test.rpm:
    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: ${GPG_KEY,,}: OK
    Payload SHA256 digest: OK"

assert_sign_args() {
  local call="$1"
  local -a expected_args=(
    --define '_openpgp_sign sq'
    --key-id "$GPG_KEY"
    --rpmv4
    --rpmv6
    --addsign
    "$rpm_dir/test.rpm"
  )
  local -a actual_args=()

  if [[ ! -f "$MOCK_SIGN_ARGS.$call" ]]; then
    echo "FAIL missing rpmsign argument capture for call $call" >&2
    return 1
  fi
  mapfile -t actual_args < "$MOCK_SIGN_ARGS.$call"
  if [[ ${#actual_args[@]} -ne ${#expected_args[@]} ]]; then
    echo "FAIL rpmsign call $call received ${#actual_args[@]} arguments, expected ${#expected_args[@]}" >&2
    return 1
  fi
  for i in "${!expected_args[@]}"; do
    if [[ "${actual_args[$i]}" != "${expected_args[$i]}" ]]; then
      echo "FAIL rpmsign call $call argument $((i + 1)): got '${actual_args[$i]}', expected '${expected_args[$i]}'" >&2
      return 1
    fi
  done
}

run_case() {
  local name="$1" expected="$2" output="$3" rc="${4:-0}"
  rm -f "$MOCK_SIGN_COUNT" "$MOCK_VERIFY_COUNT" "$MOCK_SIGN_ARGS".*
  export RPMKEYS_OUTPUT="$output" RPMKEYS_RC="$rc"
  export RETRY_SIGN_RC=0 RETRY_OUTPUT=

  local result=fail
  if "$script" --dir "$rpm_dir" --gpg-key "$GPG_KEY" --retry 0 --retry-sleep 0 >/dev/null 2>&1; then
    result=pass
  fi
  if [[ "$result" != "$expected" ]]; then
    echo "FAIL $name expected=$expected actual=$result" >&2
    return 1
  fi
  if [[ $(cat "$MOCK_VERIFY_COUNT") != 1 ]]; then
    echo "FAIL $name expected one rpmkeys invocation" >&2
    return 1
  fi
  if [[ $(cat "$MOCK_SIGN_COUNT") != 1 ]]; then
    echo "FAIL $name expected one rpmsign invocation" >&2
    return 1
  fi
  assert_sign_args 1
  echo "PASS $name"
}

run_case full-fingerprint-match pass "$fingerprint_line"
run_case long-key-id-suffix-match pass "$(printf '/tmp/test.rpm:\n    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: %s: OK' "${GPG_KEY: -16}")"
run_case short-key-id-suffix-match pass "$(printf '/tmp/test.rpm:\n    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: %s: OK' "${GPG_KEY: -8}")"
run_case key-id-field-match pass "$(printf '/tmp/test.rpm:\n    Header OpenPGP V4 RSA/SHA512 signature, Key ID %s: OK' "${GPG_KEY: -16}")"
export GPG_KEY="${GPG_KEY: -16}"
run_case long-key-id-input-matches-full-fingerprint pass "$fingerprint_line"
export GPG_KEY="${GPG_KEY: -8}"
run_case short-key-id-input-matches-full-fingerprint pass "$fingerprint_line"
export GPG_KEY=0123456789ABCDEF0123456789ABCDEF01234567
run_case wrong-full-fingerprint fail "$(printf '%s' '/tmp/test.rpm:
    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: ffffffffffffffffffffffffffffffffffffffff: OK')"

export GPG_KEY="$v6_fingerprint"
v6_fingerprint_line="$(printf '/tmp/test.rpm:\n    Header OpenPGP V6 RSA/SHA512 signature, key fingerprint: %s: OK' "$v6_fingerprint")"
run_case v6-full-fingerprint-match pass "$v6_fingerprint_line"
export GPG_KEY="${v6_fingerprint:0:16}"
run_case v6-long-key-id-matches-fingerprint-prefix pass "$v6_fingerprint_line"
export GPG_KEY="${v6_fingerprint:8:8}"
run_case v6-short-key-id-matches-fingerprint-key-id-tail pass "$v6_fingerprint_line"
export GPG_KEY="${v6_fingerprint:0:8}"
run_case v6-short-key-id-wrong-prefix-rejected fail "$v6_fingerprint_line"
export GPG_KEY="${v6_fingerprint: -16}"
run_case v6-low-order-key-id-does-not-match-fingerprint fail "$v6_fingerprint_line"
export GPG_KEY="$v6_fingerprint"
run_case v6-fingerprint-matches-explicit-key-id pass "$(printf '/tmp/test.rpm:\n    Header OpenPGP V6 RSA/SHA512 signature, Key ID %s: OK' "${v6_fingerprint:0:16}")"
export GPG_KEY="${v6_fingerprint:0:16}"
run_case v6-long-key-id-matches-short-key-id pass "$(printf '/tmp/test.rpm:\n    Header OpenPGP V6 RSA/SHA512 signature, Key ID %s: OK' "${v6_fingerprint:8:8}")"

v3_fingerprint=0123456789ABCDEF0123456789ABCDEF
export GPG_KEY="$v3_fingerprint"
run_case v3-full-fingerprint-matches-exactly pass "$(printf '/tmp/test.rpm:\n    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: %s: OK' "$v3_fingerprint")"
export GPG_KEY="${v3_fingerprint: -8}"
run_case v3-fingerprint-does-not-imply-key-id fail "$(printf '/tmp/test.rpm:\n    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: %s: OK' "$v3_fingerprint")"

export GPG_KEY=89ABCDEF
run_case short-key-id-middle-collision fail "$(printf '%s' '/tmp/test.rpm:
    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: 0123456789abcdef012345670000000000000000: OK')"
export GPG_KEY=0123456789ABCDEF
run_case long-key-id-middle-collision fail "$(printf '%s' '/tmp/test.rpm:
    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: 0123456789abcdef000000000000000000000000: OK')"
export GPG_KEY=0123456789ABCDEF0123456789ABCDEF01234567
run_case not-ok fail "$(printf '%b' "/tmp/test.rpm:\n    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: ${GPG_KEY,,}: NOT OK")"
run_case unsupported-ml-dsa fail "$(printf '%b' "/tmp/test.rpm:\n    Header OpenPGP V6 ML-DSA-65/SHA512 signature, key fingerprint: ${GPG_KEY,,}: OK")"
run_case rpmkeys-nonzero-exit fail "$fingerprint_line" 1
run_case payload-bad fail "$(printf '%b' "$fingerprint_line\n    Payload SHA256 digest: BAD (corrupt)")"

rm -f "$MOCK_SIGN_COUNT" "$MOCK_VERIFY_COUNT" "$MOCK_SIGN_ARGS".*
if "$script" --dir "$rpm_dir" --gpg-key 'not-a-hex-key' --retry 0 --retry-sleep 0 >/dev/null 2>&1; then
  echo 'FAIL invalid-key was accepted' >&2
  exit 1
fi
if [[ -e "$MOCK_SIGN_COUNT" || -e "$MOCK_VERIFY_COUNT" ]]; then
  echo 'FAIL invalid-key reached signing or verification commands' >&2
  exit 1
fi
echo 'PASS invalid-key-rejected-before-rpmsign'

rm -f "$MOCK_SIGN_COUNT" "$MOCK_VERIFY_COUNT" "$MOCK_SIGN_ARGS".*
RPMKEYS_OUTPUT="$(printf '%s' '/tmp/test.rpm:
    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: ffffffffffffffffffffffffffffffffffffffff: OK')"
RETRY_OUTPUT="$fingerprint_line"
export RPMKEYS_OUTPUT RETRY_OUTPUT
export RPMKEYS_RC=0 RETRY_SIGN_RC=1
if ! "$script" --dir "$rpm_dir" --gpg-key "$GPG_KEY" --retry 1 --retry-sleep 0 >/dev/null 2>&1; then
  echo 'FAIL retry-with-nonzero-rpmsign rejected a package that verified successfully' >&2
  exit 1
fi
if [[ $(cat "$MOCK_SIGN_COUNT") != 2 || $(cat "$MOCK_VERIFY_COUNT") != 2 ]]; then
  echo 'FAIL successful retry path did not sign and verify twice' >&2
  exit 1
fi
assert_sign_args 1
assert_sign_args 2
echo 'PASS retry-with-nonzero-rpmsign-accepts-verified-package'

rm -f "$MOCK_SIGN_COUNT" "$MOCK_VERIFY_COUNT" "$MOCK_SIGN_ARGS".*
RPMKEYS_OUTPUT="$(printf '%s' '/tmp/test.rpm:
    Header OpenPGP V4 RSA/SHA512 signature, key fingerprint: ffffffffffffffffffffffffffffffffffffffff: OK')"
RETRY_OUTPUT="$(printf '%b' "$fingerprint_line\n    Payload SHA256 digest: BAD (corrupt)")"
export RPMKEYS_OUTPUT RETRY_OUTPUT
export RPMKEYS_RC=1 RETRY_SIGN_RC=1
if "$script" --dir "$rpm_dir" --gpg-key "$GPG_KEY" --retry 1 --retry-sleep 0 >/dev/null 2>&1; then
  echo 'FAIL retry-with-nonzero-rpmsign accepted failed rpmkeys verification' >&2
  exit 1
fi
if [[ $(cat "$MOCK_VERIFY_COUNT") != 2 ]]; then
  echo 'FAIL retry path did not verify both the initial and retried package' >&2
  exit 1
fi
if [[ $(cat "$MOCK_SIGN_COUNT") != 2 || $(cat "$MOCK_VERIFY_COUNT") != 2 ]]; then
  echo 'FAIL failed retry path did not sign and verify twice' >&2
  exit 1
fi
assert_sign_args 1
assert_sign_args 2
echo 'PASS retry-with-nonzero-rpmsign-fails-closed'
