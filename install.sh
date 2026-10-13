#!/bin/sh
# Installs dn, the DecisionNode command line, from the latest GitHub release.
#
#   curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/Bynn-Intelligence/decision-node-cli/main/install.sh | sh
#
# DN_VERSION      a release tag to install, such as v0.1.0 (default: the latest)
# DN_INSTALL_DIR  where to put dn and bynn-dn (default: ~/.local/bin)
#
# The archive is always checked against the release's checksums.txt. When
# cosign is installed, the signature of checksums.txt is verified first, so the
# checksums are known to come from this project's release workflow.
#
# Every download is https only, redirects included, over TLS 1.2 or later. A
# release tag, from DN_VERSION or from the latest release, must be a version
# such as v1.2.3 or v1.2.3-rc.1 before it is used in a URL.
#
# Everything runs from main, called on the last line: a download cut short
# defines functions but runs nothing.
set -eu

REPO="Bynn-Intelligence/decision-node-cli"
# The release workflow that signs checksums.txt, keyless, through GitHub's OIDC issuer.
SIGNER_REPO="Bynn-Intelligence/decision-node-cli-source"
OIDC_ISSUER="https://token.actions.githubusercontent.com"

say() { printf '%s\n' "$*"; }
fail() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

detect_platform() {
  case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux)  os="linux" ;;
    *) fail "unsupported system $(uname -s); on Windows use Scoop: scoop install dn" ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64)  arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    # 32-bit ARM: armv8l is a 64-bit core running a 32-bit system
    armv7l|armv7*|armv8l) arch="armv7" ;;
    armv6l|armv6*) arch="armv6" ;;
    *) fail "unsupported architecture $(uname -m)" ;;
  esac
}

# fetch URL [curl options]: downloads URL over https only, TLS 1.2 or later.
fetch() {
  fetch_url="$1"
  shift
  curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --retry 3 "$@" "$fetch_url"
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

check_tools() {
  command -v curl >/dev/null 2>&1 || fail "curl is required"
  command -v tar >/dev/null 2>&1 || fail "tar is required"
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 \
    || fail "sha256sum or shasum is required to verify the download"
}

# valid_tag TAG: true when TAG is one line holding a release version such as
# v1.2.3 or v1.2.3-rc.1.
valid_tag() {
  case "$1" in
    *"
"*) return 1 ;;
  esac
  printf '%s\n' "$1" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
}

resolve_tag() {
  tag="${DN_VERSION:-}"
  if [ -n "$tag" ]; then
    valid_tag "$tag" || fail "DN_VERSION must be a release version such as v0.1.0, got '$tag'"
    return 0
  fi
  tag="$(fetch "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
  [ -n "$tag" ] || fail "cannot find the latest release of $REPO"
  valid_tag "$tag" || fail "the latest release of $REPO has an unexpected tag '$tag'"
}

# verify_signature DIR BASE_URL
# Verifies DIR/checksums.txt against its cosign signature and certificate.
# Without cosign it says so and the install continues on the checksum alone.
verify_signature() {
  if ! command -v cosign >/dev/null 2>&1; then
    say "cosign is not installed: the signature of checksums.txt is NOT verified."
    say "Continuing with the SHA-256 checksum only. Install cosign (https://docs.sigstore.dev) to verify it."
    return 0
  fi
  fetch "$2/checksums.txt.sig" -o "$1/checksums.txt.sig" \
    || fail "cannot download $2/checksums.txt.sig"
  fetch "$2/checksums.txt.pem" -o "$1/checksums.txt.pem" \
    || fail "cannot download $2/checksums.txt.pem"
  if ! cosign_out="$(cosign verify-blob \
    --certificate "$1/checksums.txt.pem" \
    --signature "$1/checksums.txt.sig" \
    --certificate-identity "https://github.com/$SIGNER_REPO/.github/workflows/release.yml@refs/tags/$tag" \
    --certificate-oidc-issuer "$OIDC_ISSUER" \
    "$1/checksums.txt" 2>&1)"; then
    printf '%s\n' "$cosign_out" >&2
    fail "the cosign signature of checksums.txt does not verify; not installing"
  fi
  say "Verified the cosign signature of checksums.txt"
}

main() {
  install_dir="${DN_INSTALL_DIR:-$HOME/.local/bin}"
  detect_platform
  check_tools
  resolve_tag

  version="${tag#v}"
  asset="dn_${version}_${os}_${arch}.tar.gz"
  base="https://github.com/$REPO/releases/download/$tag"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  trap 'exit 1' INT TERM

  say "Downloading dn $version for $os/$arch"
  fetch "$base/$asset" -o "$tmp/$asset" || fail "cannot download $base/$asset"
  fetch "$base/checksums.txt" -o "$tmp/checksums.txt" || fail "cannot download the checksums"

  verify_signature "$tmp" "$base"

  expected="$(awk -v f="$asset" '$2 == f { print $1 }' "$tmp/checksums.txt")"
  [ -n "$expected" ] || fail "$asset is not listed in checksums.txt"
  actual="$(sha256 "$tmp/$asset")"
  [ "$expected" = "$actual" ] || fail "checksum mismatch for $asset: expected $expected, got $actual"
  say "Verified the SHA-256 checksum of $asset"

  tar -xzf "$tmp/$asset" -C "$tmp" dn bynn-dn

  mkdir -p "$install_dir"
  for bin in dn bynn-dn; do
    install -m 0755 "$tmp/$bin" "$install_dir/$bin" 2>/dev/null || {
      cp "$tmp/$bin" "$install_dir/$bin" && chmod 0755 "$install_dir/$bin"
    }
  done

  say "Installed $("$install_dir/dn" version 2>/dev/null || echo "dn $version") to $install_dir"
  case ":$PATH:" in
    *":$install_dir:"*) ;;
    *) say "Add $install_dir to your PATH to run dn, for example in ~/.profile:"
       say "  export PATH=\"$install_dir:\$PATH\"" ;;
  esac
  say "Next: dn auth login"
}

main "$@"
