#!/usr/bin/env bash
# corpus#30 — a release tag must match its own VERSION. CONTRACT.md's Versioning section
# promises "every release carries a matching v<version> tag, so a consumer can pin a
# version rather than a commit SHA." That promise broke silently once already: v0.2.0
# was cut from a stale number and has described the wrong tree (0.2.0 vs the actual
# 0.4.0) since the day it was published, with nobody and nothing noticing. "Nothing
# compares the two" is the hole; this closes it.
#
# This cannot stop a bad tag from being PUSHED — git tags are pushed before any CI runs
# — but it turns a silent mismatch into a loud, immediate CI failure on the tag event
# itself, which is the earliest point any automation gets a say.
#
# Usage:
#   verify-release-tag.sh <tag> [<repo-dir>]   check <tag>'s VERSION against its own name
#   verify-release-tag.sh --self-test          prove the checker catches a mismatch
#
# <repo-dir> defaults to the current directory. Reads VERSION via `git show <tag>:VERSION`
# rather than assuming <tag> is checked out, so it can verify a tag that is not HEAD (and
# so the self-test can build a throwaway repo rather than mutating the real one).

set -euo pipefail

check_tag() {
  local tag="$1" dir="$2"
  local expected="${tag#v}"
  if [[ "$expected" == "$tag" ]]; then
    echo "release tag '$tag' does not start with 'v' — cannot derive an expected VERSION" >&2
    return 1
  fi
  local actual
  if ! actual="$(git -C "$dir" show "$tag:VERSION" 2>/dev/null)"; then
    echo "release tag '$tag': no VERSION file at that commit (git show '$tag:VERSION' failed)" >&2
    return 1
  fi
  # Trim surrounding whitespace only (CRLF, trailing newline); interior whitespace
  # makes it a different, malformed version and must not match.
  actual="${actual#"${actual%%[![:space:]]*}"}"
  actual="${actual%"${actual##*[![:space:]]}"}"
  if [[ "$actual" != "$expected" ]]; then
    echo "release tag '$tag' does not match its own VERSION: tag implies '$expected', VERSION at that commit reads '$actual'" >&2
    return 1
  fi
  echo "ok: '$tag' matches VERSION '$actual'"
  return 0
}

if [[ "${1:-}" == "--self-test" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git -C "$tmp" init -q
  git -C "$tmp" config user.email "ci@example.invalid"
  git -C "$tmp" config user.name "ci"
  # Independent of whatever the caller's global git config does with commit/tag
  # signing — this throwaway repo must not depend on a signing key being configured.
  git -C "$tmp" config commit.gpgsign false
  git -C "$tmp" config tag.gpgsign false

  # Honest release: tag name and VERSION agree.
  echo "0.1.0" > "$tmp/VERSION"
  git -C "$tmp" add VERSION
  git -C "$tmp" commit -q -m "0.1.0"
  git -C "$tmp" tag -m "v0.1.0" v0.1.0

  # The corpus#30 shape: VERSION moves on, the tag is cut from a stale number.
  echo "0.2.0" > "$tmp/VERSION"
  git -C "$tmp" add VERSION
  git -C "$tmp" commit -q -m "0.2.0"
  echo "0.4.0" > "$tmp/VERSION"
  git -C "$tmp" add VERSION
  git -C "$tmp" commit -q -m "0.4.0, but tagged as if still 0.2.0"
  git -C "$tmp" tag -m "v0.2.0" v0.2.0

  if ! check_tag v0.1.0 "$tmp" > /dev/null; then
    echo "SELF-TEST FAIL: an honestly-matching tag was rejected" >&2
    exit 1
  fi
  out=""; rc=0
  out="$(check_tag v0.2.0 "$tmp" 2>&1)" || rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "SELF-TEST FAIL: a mismatched tag (v0.2.0 vs VERSION=0.4.0) was not caught" >&2
    exit 1
  fi
  if ! printf '%s' "$out" | grep -q "implies '0.2.0', VERSION at that commit reads '0.4.0'"; then
    echo "SELF-TEST FAIL: wrong diagnostic for the mismatch: $out" >&2
    exit 1
  fi
  # Surrounding whitespace (CRLF, trailing newline) is formatting, not version.
  printf '0.5.0\r\n\n' > "$tmp/VERSION"
  git -C "$tmp" add VERSION
  git -C "$tmp" commit -q -m "0.5.0 with CRLF"
  git -C "$tmp" tag -m "v0.5.0" v0.5.0
  if ! check_tag v0.5.0 "$tmp" > /dev/null; then
    echo "SELF-TEST FAIL: a VERSION with only surrounding whitespace was rejected" >&2
    exit 1
  fi
  # ...but whitespace INSIDE the version is a different version, not formatting.
  echo "0. 6.0" > "$tmp/VERSION"
  git -C "$tmp" add VERSION
  git -C "$tmp" commit -q -m "malformed 0. 6.0"
  git -C "$tmp" tag -m "v0.6.0" v0.6.0
  if check_tag v0.6.0 "$tmp" > /dev/null 2>&1; then
    echo "SELF-TEST FAIL: VERSION '0. 6.0' was accepted as v0.6.0" >&2
    exit 1
  fi

  echo "release-tag self-test: PASS"
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "usage: verify-release-tag.sh <tag> [<repo-dir>] | --self-test" >&2
  exit 2
fi

check_tag "$1" "${2:-.}"
