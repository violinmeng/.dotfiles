#!/usr/bin/env python3
"""Audit Git objects that would be introduced by the next push.

The scanner compares a head revision with its upstream (or an explicit base),
then inspects every unique blob reachable from the head but not the base. This
includes secrets added in an intermediate commit and removed by a later one.
Finding output intentionally omits matched values.
"""

from __future__ import annotations

import argparse
import collections
import math
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import cast

DEFAULT_MAX_BLOB_MIB = 5
DEFAULT_FINDING_LIMIT = 100


class AuditError(RuntimeError):
    """Raised when the audit cannot be completed safely."""


@dataclass(frozen=True)
class AuditOptions:
    base: str | None
    head: str
    max_blob_size_mib: int
    limit: int
    fail_on_privacy: bool
    allow_unscanned: bool


@dataclass(frozen=True, order=True)
class Finding:
    path: str
    object_id: str
    line: int
    category: str

    def display(self) -> str:
        location = self.path
        if self.object_id:
            location += f"@{self.object_id}"
        if self.line:
            location += f":{self.line}"
        return f"{location} [{self.category}]"


def run_git(*args: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        ["git", *args],
        capture_output=True,
        check=False,
    )
    if check and result.returncode != 0:
        command = "git " + " ".join(args[:3])
        raise AuditError(f"{command} failed with exit code {result.returncode}")
    return result


def git_output(*args: str) -> bytes:
    return run_git(*args).stdout


def resolve_base(explicit_base: str | None) -> str:
    if explicit_base:
        return explicit_base

    result = run_git(
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{upstream}",
        check=False,
    )
    if result.returncode != 0:
        raise AuditError("no upstream is configured; pass --base <git-ref>")
    return result.stdout.decode("utf-8", "replace").strip()


def verify_commit(ref: str) -> None:
    result = run_git("rev-parse", "--verify", f"{ref}^{{commit}}", check=False)
    if result.returncode != 0:
        raise AuditError(f"ref is not a commit: {ref}")


def shannon_entropy(value: str) -> float:
    counts = collections.Counter(value)
    length = len(value)
    return -sum((count / length) * math.log2(count / length) for count in counts.values())


def is_non_loopback_ip(value: str) -> bool:
    try:
        octets = [int(part) for part in value.split(".")]
    except ValueError:
        return False
    if len(octets) != 4 or any(part < 0 or part > 255 for part in octets):
        return False
    return value not in {"0.0.0.0", "127.0.0.1", "255.255.255.255"}


def print_section(name: str, findings: set[Finding], limit: int) -> None:
    ordered = sorted(findings)
    print(f"{name}={len(ordered)}")
    for finding in ordered[:limit]:
        print(f"  {finding.display()}")
    if len(ordered) > limit:
        print(f"  ... {len(ordered) - limit} more")


def parse_args() -> AuditOptions:
    parser = argparse.ArgumentParser(
        description="Scan all Git objects that the next push would introduce.",
    )
    _ = parser.add_argument(
        "--base",
        help="base Git ref; defaults to the current branch's upstream",
    )
    _ = parser.add_argument(
        "--head",
        default="HEAD",
        help="head Git ref to audit (default: HEAD)",
    )
    _ = parser.add_argument(
        "--max-blob-size-mib",
        type=int,
        default=DEFAULT_MAX_BLOB_MIB,
        help=f"maximum text blob size to scan (default: {DEFAULT_MAX_BLOB_MIB} MiB)",
    )
    _ = parser.add_argument(
        "--limit",
        type=int,
        default=DEFAULT_FINDING_LIMIT,
        help=f"maximum findings printed per category (default: {DEFAULT_FINDING_LIMIT})",
    )
    _ = parser.add_argument(
        "--fail-on-privacy",
        action="store_true",
        help="return a failure when privacy-only findings are present",
    )
    _ = parser.add_argument(
        "--allow-unscanned",
        action="store_true",
        help="do not fail when binary or oversized blobs cannot be fully scanned",
    )
    namespace = parser.parse_args()
    options = AuditOptions(
        base=cast(str | None, namespace.base),
        head=cast(str, namespace.head),
        max_blob_size_mib=cast(int, namespace.max_blob_size_mib),
        limit=cast(int, namespace.limit),
        fail_on_privacy=cast(bool, namespace.fail_on_privacy),
        allow_unscanned=cast(bool, namespace.allow_unscanned),
    )
    if options.max_blob_size_mib <= 0:
        parser.error("--max-blob-size-mib must be greater than zero")
    if options.limit <= 0:
        parser.error("--limit must be greater than zero")
    return options


HARD_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("private-key", re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----")),
    ("aws-access-key", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("github-token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{20,255})\b")),
    ("gitlab-token", re.compile(r"\bglpat-[A-Za-z0-9_-]{20,}\b")),
    ("slack-token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("google-api-key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("openai-key", re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    ("anthropic-key", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}\b")),
    ("stripe-secret", re.compile(r"\b(?:sk|rk)_live_[A-Za-z0-9]{16,}\b")),
    ("npm-token", re.compile(r"\bnpm_[A-Za-z0-9]{30,}\b")),
    ("pypi-token", re.compile(r"\bpypi-[A-Za-z0-9_-]{30,}\b")),
    ("basic-auth-url", re.compile(r"https?://[^\s/@:]+:[^\s/@]+@")),
    ("ssh-private-key-material", re.compile(r"\bopenssh-key-v1\b")),
]

GENERIC_ASSIGNMENT: re.Pattern[str] = re.compile(
    r'''(?ix)
    ["']?\b(api[_-]?key|access[_-]?token|auth[_-]?token|bearer[_-]?token|
    secret(?:[_-]?key)?|password|passwd|client[_-]?secret|private[_-]?key)\b["']?
    \s*[:=]\s*["']?([^"'\s,}\]]{6,})
    ''',
)

SENSITIVE_PATH: re.Pattern[str] = re.compile(
    r'''(?ix)(?:^|/)(?:
    \.env(?:\.[^/]*)?|id_(?:rsa|dsa|ecdsa|ed25519)(?:\.pub)?|auth\.json|
    credentials?(?:\.[^/]*)?|secrets?(?:\.[^/]*)?|[^/]+\.(?:pem|p12|pfx|key|jks|keystore)
    )$''',
)

ENTROPY_TOKEN: re.Pattern[str] = re.compile(
    r"(?<![A-Za-z0-9])[A-Za-z0-9_+/=-]{32,}(?![A-Za-z0-9])"
)
EMAIL: re.Pattern[str] = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
IPV4: re.Pattern[str] = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
ABSOLUTE_HOME: re.Pattern[str] = re.compile(r"(?:/Users|/home)/[A-Za-z0-9._-]+/")

PLACEHOLDER_FRAGMENTS: tuple[str, ...] = (
    "example",
    "sample",
    "placeholder",
    "changeme",
    "replace_me",
    "replace-me",
    "your_",
    "your-",
    "dummy",
    "test",
    "none",
    "null",
    "false",
    "true",
    "redacted",
    "process.env",
    "getenv",
    "env[",
    "${",
    "$",
    "<",
    "***",
    "xxx",
)

NON_PERSONAL_EMAILS: set[str] = {
    "git@github.com",
    "git@gitlab.com",
    "git@bitbucket.org",
}


def main() -> int:
    args = parse_args()
    base = resolve_base(args.base)
    head = args.head
    verify_commit(base)
    verify_commit(head)

    max_blob_size = args.max_blob_size_mib * 1024 * 1024
    base_is_ancestor = run_git("merge-base", "--is-ancestor", base, head, check=False).returncode == 0
    dirty = bool(git_output("status", "--porcelain").strip())
    outgoing_commits = git_output("rev-list", f"{base}..{head}").decode().splitlines()
    object_records = git_output("rev-list", "--objects", head, f"^{base}").decode(
        "utf-8", "replace"
    ).splitlines()
    changed_paths = {
        path.strip()
        for path in git_output("log", "--format=", "--name-only", "-z", f"{base}..{head}")
        .decode("utf-8", "replace")
        .split("\0")
        if path.strip()
    }

    hard_findings: set[Finding] = set()
    generic_findings: set[Finding] = set()
    entropy_findings: set[Finding] = set()
    sensitive_path_findings: set[Finding] = set()
    commit_findings: set[Finding] = set()
    privacy_findings: set[Finding] = set()
    unscanned_findings: set[Finding] = set()

    for path in changed_paths:
        if SENSITIVE_PATH.search(path):
            sensitive_path_findings.add(Finding(path, "", 0, "sensitive-filename"))

    for remote in git_output("remote").decode("utf-8", "replace").splitlines():
        push_url_result = run_git("remote", "get-url", "--push", remote, check=False)
        if push_url_result.returncode != 0:
            continue
        push_url = push_url_result.stdout.decode("utf-8", "replace").strip()
        if re.search(r"https?://[^/:@\s]+:[^/@\s]+@", push_url):
            hard_findings.add(Finding(f"<remote:{remote}>", "", 0, "credential-in-push-url"))

    for commit_id in outgoing_commits:
        short_id = commit_id[:12]
        message = git_output("show", "-s", "--format=%B", commit_id).decode("utf-8", "replace")
        for category, pattern in HARD_PATTERNS:
            if pattern.search(message):
                commit_findings.add(Finding("<commit-message>", short_id, 0, category))

        metadata = git_output("show", "-s", "--format=%ae%n%ce", commit_id).decode(
            "utf-8", "replace"
        )
        if EMAIL.search(metadata):
            privacy_findings.add(Finding("<commit-metadata>", short_id, 0, "author-or-committer-email"))

    seen_blobs: set[str] = set()
    text_blobs_scanned = 0
    binary_blobs = 0
    oversized_blobs = 0

    for record in object_records:
        object_id, _, path = record.partition(" ")
        object_type = git_output("cat-file", "-t", object_id).decode().strip()
        if object_type != "blob":
            continue

        if path and SENSITIVE_PATH.search(path):
            sensitive_path_findings.add(Finding(path, object_id[:12], 0, "sensitive-filename"))
        if object_id in seen_blobs:
            continue
        seen_blobs.add(object_id)

        data = git_output("cat-file", "blob", object_id)
        display_path = path or "<unknown>"
        if len(data) > max_blob_size:
            oversized_blobs += 1
            unscanned_findings.add(
                Finding(display_path, object_id[:12], 0, f"oversized-blob:{len(data)}-bytes")
            )
            continue
        if b"\x00" in data[:8192]:
            binary_blobs += 1
            unscanned_findings.add(Finding(display_path, object_id[:12], 0, "binary-blob"))
            continue

        text_blobs_scanned += 1
        text = data.decode("utf-8", "replace")
        for line_number, line in enumerate(text.splitlines(), 1):
            for category, pattern in HARD_PATTERNS:
                if pattern.search(line):
                    hard_findings.add(Finding(display_path, object_id[:12], line_number, category))

            for match in GENERIC_ASSIGNMENT.finditer(line):
                key = match.group(1).lower()
                value = match.group(2)
                lowered = value.lower()
                if not any(fragment in lowered for fragment in PLACEHOLDER_FRAGMENTS):
                    generic_findings.add(Finding(display_path, object_id[:12], line_number, key))

            if ABSOLUTE_HOME.search(line):
                privacy_findings.add(
                    Finding(display_path, object_id[:12], line_number, "absolute-home-path")
                )

            for email_match in EMAIL.finditer(line):
                email = email_match.group(0).lower()
                if email not in NON_PERSONAL_EMAILS and not email.endswith("@example.com"):
                    privacy_findings.add(
                        Finding(display_path, object_id[:12], line_number, "email-address")
                    )

            for ip_match in IPV4.finditer(line):
                ip = ip_match.group(0)
                if is_non_loopback_ip(ip):
                    privacy_findings.add(
                        Finding(display_path, object_id[:12], line_number, "non-loopback-ip-address")
                    )

            for token_match in ENTROPY_TOKEN.finditer(line):
                token = token_match.group(0)
                stripped = token.rstrip("=")
                if re.fullmatch(r"[0-9a-fA-F]{32,}", stripped):
                    continue
                if token.startswith(("http", "npm:", "git:")):
                    continue
                character_classes = sum(
                    bool(re.search(pattern, stripped))
                    for pattern in (r"[a-z]", r"[A-Z]", r"\d")
                )
                if (
                    len(stripped) >= 32
                    and character_classes >= 3
                    and shannon_entropy(stripped) >= 4.5
                ):
                    entropy_findings.add(
                        Finding(
                            display_path,
                            object_id[:12],
                            line_number,
                            f"high-entropy-token:{len(stripped)}-chars",
                        )
                    )

    print(f"base={base}")
    print(f"head={head}")
    print(f"base_is_ancestor={str(base_is_ancestor).lower()}")
    print(f"working_tree_dirty={str(dirty).lower()}")
    print(f"outgoing_commits={len(outgoing_commits)}")
    print(f"unique_outgoing_objects={len(object_records)}")
    print(f"text_blobs_scanned={text_blobs_scanned}")
    print(f"binary_blobs_skipped={binary_blobs}")
    print(f"oversized_blobs_skipped={oversized_blobs}")

    print_section("hard_findings", hard_findings, args.limit)
    print_section("generic_secret_assignments", generic_findings, args.limit)
    print_section("high_entropy_candidates", entropy_findings, args.limit)
    print_section("sensitive_paths", sensitive_path_findings, args.limit)
    print_section("commit_message_findings", commit_findings, args.limit)
    print_section("privacy_only_findings", privacy_findings, args.limit)
    print_section("unscanned_blobs", unscanned_findings, args.limit)

    blocking_findings = (
        hard_findings
        or generic_findings
        or sensitive_path_findings
        or commit_findings
    )
    if blocking_findings:
        print("result=BLOCKED")
        return 2
    if entropy_findings:
        print("result=REVIEW_REQUIRED")
        return 3
    if unscanned_findings and not args.allow_unscanned:
        print("result=INCOMPLETE")
        return 5
    if privacy_findings and args.fail_on_privacy:
        print("result=PRIVACY_REVIEW_REQUIRED")
        return 4

    print("result=PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AuditError as error:
        print(f"audit_error={error}", file=sys.stderr)
        raise SystemExit(1)
    except KeyboardInterrupt:
        print("audit_error=interrupted", file=sys.stderr)
        raise SystemExit(130)
