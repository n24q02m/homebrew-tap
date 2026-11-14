#!/usr/bin/env python3
"""Point a Homebrew formula and a Scoop manifest at a published registry release.

Both package managers install the same artifact the registry serves, so the
version, URL and checksum are read from the registry rather than typed by hand:

* PyPI tools: both install the pure wheel; uv resolves its dependencies.
* npm tools: both install the registry tarball.

Usage (from a source repository's CD, after a stable release is published)::

    python homebrew-tap/scripts/bump.py wet \
        --formula homebrew-tap/Formula/wet.rb \
        --manifest scoop-bucket/bucket/wet.json

``--version`` defaults to the registry's latest stable release. ``--check`` rewrites
nothing and exits 1 when either file is behind that release.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

PYPI = "pypi"
NPM = "npm"

# Package-manager name -> (registry, distribution name on that registry).
PACKAGES: dict[str, tuple[str, str]] = {
    "wet": (PYPI, "n24q02m-wet"),
    "mnemo": (PYPI, "n24q02m-mnemo"),
    "crg": (PYPI, "n24q02m-crg"),
    "telegram": (PYPI, "n24q02m-telegram"),
    "notion": (NPM, "@n24q02m/notion"),
    "email": (NPM, "@n24q02m/email"),
    "workspace": (NPM, "@n24q02m/workspace"),
}

STABLE = re.compile(r"\d+(\.\d+)*")


@dataclass(frozen=True)
class Artifact:
    url: str
    sha256: str


@dataclass(frozen=True)
class Release:
    version: str
    formula: Artifact
    manifest: Artifact


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "n24q02m-tap-bump"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def _get_json(url: str) -> dict:
    return json.loads(_get(url))


def resolve_pypi(
    dist: str, version: str | None, get_json: Callable[[str], dict] = _get_json
) -> Release:
    if version is None:
        version = get_json(f"https://pypi.org/pypi/{dist}/json")["info"]["version"]
    files = get_json(f"https://pypi.org/pypi/{dist}/{version}/json")["urls"]
    wheel = [
        f
        for f in files
        if f["packagetype"] == "bdist_wheel"
        and f["filename"].endswith("-py3-none-any.whl")
    ]
    if len(wheel) != 1:
        raise SystemExit(
            f"{dist} {version}: expected one pure wheel, got {[f['filename'] for f in files]}"
        )
    w = wheel[0]
    return Release(
        version=version,
        formula=Artifact(w["url"], w["digests"]["sha256"]),
        # Scoop keeps the file name after `#/`, so the installer can pass the wheel to uv as-is.
        manifest=Artifact(f"{w['url']}#/{w['filename']}", w["digests"]["sha256"]),
    )


def resolve_npm(
    name: str,
    version: str | None,
    get_json: Callable[[str], dict] = _get_json,
    get: Callable[[str], bytes] = _get,
) -> Release:
    if version is None:
        version = get_json(f"https://registry.npmjs.org/{name}")["dist-tags"]["latest"]
    tarball = get_json(f"https://registry.npmjs.org/{name}/{version}")["dist"][
        "tarball"
    ]
    # npm publishes sha1/sha512 only; both package managers pin sha256.
    digest = hashlib.sha256(get(tarball)).hexdigest()
    art = Artifact(tarball, digest)
    return Release(version=version, formula=art, manifest=art)


def resolve(package: str, version: str | None) -> Release:
    registry, dist = PACKAGES[package]
    release = (
        resolve_pypi(dist, version) if registry == PYPI else resolve_npm(dist, version)
    )
    if not STABLE.fullmatch(release.version):
        raise SystemExit(
            f"{package} {release.version} is a prerelease; the tap and bucket carry stable releases only"
        )
    return release


def rewrite_formula(text: str, art: Artifact) -> str:
    text, n_url = re.subn(
        r'^(  url )"[^"]*"', rf'\1"{art.url}"', text, count=1, flags=re.MULTILINE
    )
    text, n_sha = re.subn(
        r'^(  sha256 )"[0-9a-f]{64}"',
        rf'\1"{art.sha256}"',
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if n_url != 1 or n_sha != 1:
        raise SystemExit("formula has no top-level url/sha256 pair to rewrite")
    return text


def rewrite_manifest(text: str, release: Release) -> str:
    data = json.loads(text)
    data["version"] = release.version
    data["url"] = release.manifest.url
    data["hash"] = release.manifest.sha256
    return json.dumps(data, indent=4, ensure_ascii=False) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("package", choices=sorted(PACKAGES))
    parser.add_argument(
        "--version", help="release to point at (default: registry latest)"
    )
    parser.add_argument("--formula", type=Path, help="Formula/<name>.rb to rewrite")
    parser.add_argument("--manifest", type=Path, help="bucket/<name>.json to rewrite")
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 when a file is behind; write nothing",
    )
    args = parser.parse_args(argv)
    if not args.formula and not args.manifest:
        parser.error("pass --formula and/or --manifest")

    release = resolve(args.package, args.version)
    behind = []
    targets = [
        (args.formula, lambda t: rewrite_formula(t, release.formula)),
        (args.manifest, lambda t: rewrite_manifest(t, release)),
    ]
    for path, rewrite in targets:
        if path is None:
            continue
        old = path.read_text(encoding="utf-8")
        new = rewrite(old)
        if new == old:
            print(f"{path}: already at {args.package} {release.version}")
            continue
        behind.append(str(path))
        if args.check:
            print(f"{path}: behind {args.package} {release.version}")
        else:
            path.write_text(new, encoding="utf-8", newline="\n")
            print(f"{path}: now at {args.package} {release.version}")
    return 1 if args.check and behind else 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
