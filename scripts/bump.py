#!/usr/bin/env python3
"""Point a Homebrew formula and a Scoop manifest at a published registry release.

Both package managers install the artifact the registry serves, and every
dependency it pulls in is pinned by a hash that this script regenerates:

* PyPI tools install the pure wheel plus two lock files. ``locks/<name>-<version>.txt``
  is the release tag's ``uv.lock`` exported as hashed requirements (when the release
  publishes its own ``requirements.lock`` asset, the export must match it byte for byte);
  ``locks/<name>-<version>.build.txt`` holds the hashed build backends of any
  dependency that publishes only an sdist. The installers run
  ``uv pip install --require-hashes --only-binary :all: --no-deps`` (build backends
  first, then the lock with ``--no-build-isolation``), so nothing unhashed runs.
* npm tools install the registry tarball plus ``locks/<name>-<version>.package-lock.json``:
  the tarball's own ``npm-shrinkwrap.json`` (the tree the release was tested with) when it
  ships one, else a lock resolved from the published ``package.json`` as of the publish
  time. Every installed entry must carry an integrity hash, and the installers run
  ``npm ci --omit=dev --ignore-scripts``, which checks each one.

Lock files live in ``locks/`` next to ``Formula/`` or ``bucket/``; the formula or
manifest names each one by URL and sha256.

Usage (``bump.yml`` in each repository runs this on ``workflow_dispatch``)::

    python scripts/bump.py wet --formula Formula/wet.rb
    python scripts/bump.py wet --manifest bucket/wet.json

``--version`` defaults to the registry's latest stable release. ``--check`` writes
nothing and exits 1 when a file is behind that release or names a lock file that is
missing or does not match its sha256. ``--pinned`` checks the release the files already
name instead, so CI can gate a pull request on its own files while a newer release of
another tool is still waiting for its bump.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import tomllib
import urllib.error
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

PYPI = "pypi"
NPM = "npm"

# Both package managers run the Python tools on CPython 3.13 (`python@3.13`, `uv venv --python 3.13`).
PYTHON = "3.13"


@dataclass(frozen=True)
class Tool:
    registry: str
    dist: str
    # GitHub repository under n24q02m; release tags are `v<version>`.
    repo: str


PACKAGES: dict[str, Tool] = {
    "wet": Tool(PYPI, "n24q02m-wet", "wet"),
    "mnemo": Tool(PYPI, "n24q02m-mnemo", "mnemo"),
    "crg": Tool(PYPI, "n24q02m-crg", "crg"),
    "telegram": Tool(PYPI, "n24q02m-telegram", "telegram"),
    "notion": Tool(NPM, "@n24q02m/notion", "notion"),
    "email": Tool(NPM, "@n24q02m/email", "email"),
    "workspace": Tool(NPM, "@n24q02m/workspace", "workspace"),
}

STABLE = re.compile(r"\d+(\.\d+)*")

# Each Python release publishes the lock its CD job installed and tested, built with the
# same `uv export` flags as `python_locks`; older releases predate the asset.
RELEASE_LOCK = "requirements.lock"

# PEP 517: an sdist without a [build-system] table builds with legacy setuptools.
DEFAULT_BUILD_REQUIRES = ["setuptools>=40.8.0"]

# Registry reads run in CI and in bump.yml, where a dropped TLS handshake or a
# 5xx/429 is routine; a 4xx is an answer and fails at once.
ATTEMPTS = 4


@dataclass(frozen=True)
class Artifact:
    url: str
    sha256: str


@dataclass(frozen=True)
class Release:
    version: str
    formula: Artifact
    manifest: Artifact
    # Registry upload time (ISO 8601); dependency resolution is cut off there so a
    # regenerated lock for the same release does not drift.
    published: str


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "n24q02m-tap-bump"})
    for attempt in range(1, ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except urllib.error.URLError as err:
            code = getattr(err, "code", None)
            client_error = code is not None and code < 500 and code != 429
            if client_error or attempt == ATTEMPTS:
                raise
            time.sleep(2**attempt)
    raise AssertionError("unreachable")  # pragma: no cover


def _get_json(url: str) -> dict:
    return json.loads(_get(url))


def _run(cmd: list[str], cwd: Path | None = None) -> str:
    exe = shutil.which(cmd[0])
    if exe is None:
        raise SystemExit(f"{cmd[0]} is not on PATH")
    done = subprocess.run(
        [exe, *cmd[1:]], cwd=cwd, check=True, capture_output=True, text=True
    )
    return done.stdout


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _normalize(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


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
        published=w["upload_time_iso_8601"],
    )


def resolve_npm(
    name: str,
    version: str | None,
    get_json: Callable[[str], dict] = _get_json,
    get: Callable[[str], bytes] = _get,
) -> Release:
    doc = get_json(f"https://registry.npmjs.org/{name}")
    if version is None:
        version = doc["dist-tags"]["latest"]
    tarball = doc["versions"][version]["dist"]["tarball"]
    # npm publishes sha1/sha512 only; both package managers pin sha256.
    art = Artifact(tarball, _sha256(get(tarball)))
    return Release(
        version=version, formula=art, manifest=art, published=doc["time"][version]
    )


def resolve(package: str, version: str | None) -> Release:
    tool = PACKAGES[package]
    release = (
        resolve_pypi(tool.dist, version)
        if tool.registry == PYPI
        else resolve_npm(tool.dist, version)
    )
    if not STABLE.fullmatch(release.version):
        raise SystemExit(
            f"{package} {release.version} is a prerelease; the tap and bucket carry stable releases only"
        )
    return release


def lock_names(package: str, version: str) -> list[str]:
    stem = f"{package}-{version}"
    if PACKAGES[package].registry == PYPI:
        return [f"{stem}.txt", f"{stem}.build.txt"]
    return [f"{stem}.package-lock.json"]


def lock_kind(filename: str) -> str:
    """The part of a lock file name after `<package>-<version>`."""
    for kind in (".build.txt", ".package-lock.json", ".txt"):
        if filename.endswith(kind):
            return kind
    raise SystemExit(f"{filename} is not a lock file name")


def pinned_version(package: str, text: str) -> str:
    """The release a formula or manifest already names, read from its lock file URLs."""
    found = set(
        re.findall(
            rf"/locks/{re.escape(package)}-(\d[^\"#/]*?)(?:\.build\.txt|\.package-lock\.json|\.txt)(?=[\"#])",
            text,
        )
    )
    if len(found) != 1:
        raise SystemExit(
            f"lock file URLs name {sorted(found) or 'no'} {package} release(s); expected one"
        )
    return found.pop()


# `name==version ; marker \` as `uv export` writes each pin.
REQUIREMENT = re.compile(
    r"^([A-Za-z0-9][A-Za-z0-9._-]*)==([^\s;\\]+)(?: ; ([^\\\n]+?))?\s*\\?$",
    re.MULTILINE,
)

# The platforms the tap and bucket serve, as PEP 508 marker variables.
PLATFORMS = (
    {"sys_platform": "darwin", "platform_system": "Darwin", "os_name": "posix"},
    {"sys_platform": "win32", "platform_system": "Windows", "os_name": "nt"},
    {"sys_platform": "linux", "platform_system": "Linux", "os_name": "posix"},
)

MARKER_TOKEN = re.compile(
    r"\s*(?:(\()|(\))|(and|or)\b|([a-z_]+)\s*(==|!=|<=|>=|~=|===|<|>|not in|in)\s*'([^']*)')"
)


def _marker_value(marker: str, env: dict[str, str]) -> bool | None:
    """Evaluate a marker with three-valued logic: None when it depends on a variable
    `env` does not fix (machine, Python patch version, ...)."""
    tokens: list[tuple] = []
    pos = 0
    while pos < len(marker.rstrip()):
        m = MARKER_TOKEN.match(marker, pos)
        if m is None:
            return None
        tokens.append(m.groups())
        pos = m.end()

    def atom(i: int) -> tuple[bool | None, int]:
        lparen, _, _, var, op, value = tokens[i]
        if lparen:
            val, i = expr(i + 1)
            return val, i + 1
        if var in env and op in ("==", "!="):
            return (env[var] == value) == (op == "=="), i + 1
        return None, i + 1

    def chain(i: int, word: str, sub: Callable) -> tuple[bool | None, int]:
        vals = []
        val, i = sub(i)
        vals.append(val)
        while i < len(tokens) and tokens[i][2] == word:
            val, i = sub(i + 1)
            vals.append(val)
        stop, other = (False, True) if word == "and" else (True, False)
        if stop in vals:
            return stop, i
        return (other if all(v is other for v in vals) else None), i

    def expr(i: int) -> tuple[bool | None, int]:
        return chain(i, "or", lambda j: chain(j, "and", atom))

    try:
        val, end = expr(0)
    except IndexError:
        return None
    return val if end == len(tokens) else None


def marker_reachable(marker: str) -> bool:
    return any(_marker_value(marker, env) is not False for env in PLATFORMS)


def build_requires(sdist: bytes) -> list[str]:
    """The [build-system] requires of an sdist (.tar.gz), read without extracting it."""
    with tarfile.open(fileobj=io.BytesIO(sdist), mode="r:gz") as tar:
        top = [m for m in tar.getmembers() if m.name.count("/") == 1]
        pyproject = [m for m in top if m.name.endswith("/pyproject.toml")]
        if not pyproject:
            return list(DEFAULT_BUILD_REQUIRES)
        data = tomllib.loads(tar.extractfile(pyproject[0]).read().decode("utf-8"))
    return list(data.get("build-system", {}).get("requires", DEFAULT_BUILD_REQUIRES))


def release_lock_url(tool: Tool, version: str) -> str:
    return f"https://github.com/n24q02m/{tool.repo}/releases/download/v{version}/{RELEASE_LOCK}"


def release_lock(
    tool: Tool, version: str, get: Callable[[str], bytes] = _get
) -> bytes | None:
    """The release's `requirements.lock` asset, or None for a release published before it."""
    try:
        return get(release_lock_url(tool, version))
    except urllib.error.HTTPError as err:
        if err.code == 404:
            return None
        raise


def python_locks(
    package: str,
    release: Release,
    get: Callable[[str], bytes] = _get,
    run: Callable[..., str] = _run,
) -> dict[str, bytes]:
    tool = PACKAGES[package]
    txt, build = lock_names(package, release.version)
    base = f"https://raw.githubusercontent.com/n24q02m/{tool.repo}/v{release.version}/"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for name in ("pyproject.toml", "uv.lock"):
            (root / name).write_bytes(get(base + name))
        lock = tomllib.loads((root / "uv.lock").read_text(encoding="utf-8"))["package"]
        # The release pipeline bumps pyproject.toml, not the project's own entry in
        # uv.lock, so match the name only; `uv pip check` after installing the wheel
        # proves the lock satisfies the released requirements.
        project = [p for p in lock if p.get("source", {}).get("editable") == "."]
        if [_normalize(p["name"]) for p in project] != [_normalize(tool.dist)]:
            raise SystemExit(
                f"{tool.repo} v{release.version}: uv.lock does not lock {tool.dist}"
            )
        exported = run(
            [
                "uv",
                "export",
                "--frozen",
                "--no-dev",
                "--no-emit-project",
                "--no-header",
                "--format",
                "requirements-txt",
                "--project",
                str(root),
            ]
        )
        published = release_lock(tool, release.version, get)
        if published is None:
            source = ""
            print(
                f"::warning::{tool.repo} v{release.version} has no {RELEASE_LOCK} asset;"
                " the lock comes from the tag's uv.lock alone"
            )
        elif published != exported.encode("utf-8"):
            raise SystemExit(
                f"{tool.repo} v{release.version}: {RELEASE_LOCK} differs from the uv.lock export"
            )
        else:
            source = (
                f"# Identical to the release asset {release_lock_url(tool, release.version)}\n"
                f"# (sha256 {_sha256(published)}).\n"
            )
        # A pin whose marker holds on no served platform (an override such as
        # `; sys_platform == 'unreachable'`) is never installed, so it needs no backend.
        installed = {
            (_normalize(m.group(1)), m.group(2))
            for m in REQUIREMENT.finditer(exported)
            if m.group(3) is None or marker_reachable(m.group(3))
        }
        sdist_only = sorted(
            (
                p
                for p in lock
                if (_normalize(p["name"]), p.get("version")) in installed
                and not p.get("wheels")
            ),
            key=lambda p: _normalize(p["name"]),
        )
        requires: list[str] = []
        for p in sdist_only:
            sdist = p["sdist"]
            data = get(sdist["url"])
            if "sha256:" + _sha256(data) != sdist["hash"]:
                raise SystemExit(f"{p['name']} sdist does not match uv.lock")
            requires += build_requires(data)
        header = (
            f"# {tool.dist} {release.version}: every runtime dependency, exported from\n"
            f"# n24q02m/{tool.repo}@v{release.version} uv.lock by scripts/bump.py.\n"
            + source
        )
        no_binary = "".join(
            f"--no-binary {_normalize(p['name'])}\n" for p in sdist_only
        )
        build_header = (
            f"# {tool.dist} {release.version}: build backends for the dependencies that\n"
            "# publish only an sdist, resolved by scripts/bump.py.\n"
        )
        if requires:
            (root / "build.in").write_text("\n".join(requires) + "\n", encoding="utf-8")
            compiled = run(
                [
                    "uv",
                    "pip",
                    "compile",
                    "--generate-hashes",
                    "--universal",
                    "--python-version",
                    PYTHON,
                    "--only-binary",
                    ":all:",
                    "--exclude-newer",
                    release.published,
                    "--no-header",
                    "--no-annotate",
                    str(root / "build.in"),
                ]
            )
        else:
            compiled = "# None: every dependency installs from a wheel.\n"
    return {
        txt: (header + no_binary + exported).encode("utf-8"),
        build: (build_header + compiled).encode("utf-8"),
    }


def npm_locks(
    package: str,
    release: Release,
    get: Callable[[str], bytes] = _get,
    run: Callable[..., str] = _run,
) -> dict[str, bytes]:
    (name,) = lock_names(package, release.version)
    data = get(release.formula.url)
    if _sha256(data) != release.formula.sha256:
        raise SystemExit(f"{release.formula.url} changed while bumping")
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
        manifest = tar.extractfile("package/package.json").read()
        try:
            lock = tar.extractfile("package/npm-shrinkwrap.json").read()
        except KeyError:
            lock = None
    if lock is None:
        print(
            f"::warning::{package} {release.version} ships no npm-shrinkwrap.json;"
            " resolving its package.json as of the publish time"
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "package.json").write_bytes(manifest)
            run(
                [
                    "npm",
                    "install",
                    "--package-lock-only",
                    "--ignore-scripts",
                    "--no-audit",
                    "--no-fund",
                    f"--before={release.published}",
                ],
                cwd=root,
            )
            lock = (root / "package-lock.json").read_bytes()
    check_npm_lock(f"{package} {release.version}", lock)
    return {name: lock}


def check_npm_lock(where: str, body: bytes) -> None:
    """Fail unless every entry `npm ci --omit=dev` installs names a URL and an integrity hash.

    Dev entries are never installed and bundled entries arrive inside their parent's
    tarball, so neither needs a hash of its own."""
    packages = json.loads(body).get("packages")
    if not isinstance(packages, dict):
        raise SystemExit(
            f"{where}: the npm lock has no `packages` map (lockfileVersion 2+)"
        )
    unpinned = sorted(
        path
        for path, entry in packages.items()
        if path
        and not entry.get("dev")
        and not entry.get("inBundle")
        and not (entry.get("resolved") and entry.get("integrity"))
    )
    if unpinned:
        raise SystemExit(
            f"{where}: npm lock entries without resolved+integrity: {unpinned}"
        )


def build_locks(package: str, release: Release) -> dict[str, bytes]:
    if PACKAGES[package].registry == PYPI:
        return python_locks(package, release)
    return npm_locks(package, release)


def _relock(url: str, locks: dict[str, str]) -> tuple[str, str]:
    """The lock URL rewritten to the file of the same kind in `locks`, and its sha256."""
    prefix, _, old = url.rpartition("/")
    (new,) = [n for n in locks if lock_kind(n) == lock_kind(old)]
    return f"{prefix}/{new}", locks[new]


def _check_kinds(where: str, urls: list[str], locks: dict[str, str]) -> None:
    have = sorted(lock_kind(u.rpartition("/")[2]) for u in urls)
    want = sorted(lock_kind(n) for n in locks)
    if have != want:
        raise SystemExit(f"{where} names lock files {have}; this release needs {want}")


LOCK_RESOURCE = re.compile(
    r'^(    url ")(https://raw\.githubusercontent\.com/[^"]+/locks/[^"]+)("\n    sha256 ")[0-9a-f]{64}"',
    re.MULTILINE,
)


def rewrite_formula(text: str, art: Artifact, locks: dict[str, str]) -> str:
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
    _check_kinds("formula", [m.group(2) for m in LOCK_RESOURCE.finditer(text)], locks)

    def relock(m: re.Match) -> str:
        url, sha = _relock(m.group(2), locks)
        return f'{m.group(1)}{url}{m.group(3)}{sha}"'

    return LOCK_RESOURCE.sub(relock, text)


def rewrite_manifest(text: str, release: Release, locks: dict[str, str]) -> str:
    data = json.loads(text)
    urls, hashes = data.get("url"), data.get("hash")
    if (
        not isinstance(urls, list)
        or not isinstance(hashes, list)
        or len(urls) != len(hashes)
    ):
        raise SystemExit(
            "manifest needs matching url and hash lists (artifact, then locks)"
        )
    # `#/<name>` fixes the downloaded file name the installer reads.
    split = [u.partition("#") for u in urls[1:]]
    _check_kinds("manifest", [u for u, _, _ in split], locks)
    data["version"] = release.version
    data["url"] = [release.manifest.url]
    data["hash"] = [release.manifest.sha256]
    for url, sep, fragment in split:
        new, sha = _relock(url, locks)
        data["url"].append(new + sep + fragment)
        data["hash"].append(sha)
    return json.dumps(data, indent=4, ensure_ascii=False) + "\n"


def write_locks(lock_dir: Path, package: str, locks: dict[str, bytes]) -> None:
    """Write this release's lock files and drop the package's older ones."""
    lock_dir.mkdir(exist_ok=True)
    stale = re.compile(rf"{re.escape(package)}-\d")
    for old in lock_dir.iterdir():
        if stale.match(old.name) and old.name not in locks:
            old.unlink()
    for name, body in locks.items():
        (lock_dir / name).write_bytes(body)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("package", choices=sorted(PACKAGES))
    which = parser.add_mutually_exclusive_group()
    which.add_argument(
        "--version", help="release to point at (default: registry latest)"
    )
    which.add_argument(
        "--pinned",
        action="store_true",
        help="use the release the files already name (CI checks them against the registry)",
    )
    parser.add_argument("--formula", type=Path, help="Formula/<name>.rb to rewrite")
    parser.add_argument("--manifest", type=Path, help="bucket/<name>.json to rewrite")
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 when a file is behind or a lock file is missing; write nothing",
    )
    args = parser.parse_args(argv)
    if not args.formula and not args.manifest:
        parser.error("pass --formula and/or --manifest")

    version = args.version
    if args.pinned:
        found = {
            pinned_version(args.package, p.read_text(encoding="utf-8"))
            for p in (args.formula, args.manifest)
            if p is not None
        }
        if len(found) != 1:
            raise SystemExit(
                f"formula and manifest name different releases: {sorted(found)}"
            )
        (version,) = found
    release = resolve(args.package, version)
    names = lock_names(args.package, release.version)
    generated = None if args.check else build_locks(args.package, release)
    behind = []
    targets = [
        (args.formula, lambda t, d: rewrite_formula(t, release.formula, d)),
        (args.manifest, lambda t, d: rewrite_manifest(t, release, d)),
    ]
    for path, rewrite in targets:
        if path is None:
            continue
        # Formula/<name>.rb and bucket/<name>.json sit one level below the repository root.
        lock_dir = path.resolve().parent.parent / "locks"
        if generated is None:
            missing = [n for n in names if not (lock_dir / n).is_file()]
            if missing:
                print(
                    f"{path}: lock files missing for {args.package} {release.version}: {missing}"
                )
                behind.append(str(path))
                continue
            bodies = {n: (lock_dir / n).read_bytes() for n in names}
        else:
            bodies = generated
        old = path.read_text(encoding="utf-8")
        new = rewrite(old, {n: _sha256(b) for n, b in bodies.items()})
        if generated is not None:
            write_locks(lock_dir, args.package, generated)
        if new == old:
            print(f"{path}: already at {args.package} {release.version}")
            continue
        behind.append(str(path))
        if args.check:
            print(f"{path}: behind {args.package} {release.version}")
        else:
            path.write_text(new, encoding="utf-8", newline="\n")
            print(f"{path}: now at {args.package} {release.version}")
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as fh:
            fh.write(f"version={release.version}\n")
    return 1 if args.check and behind else 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
