"""Offline tests for bump.py: registry reads and subprocesses are replaced by fixtures."""

import hashlib
import io
import json
import os
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import bump

SDIST = {
    "packagetype": "sdist",
    "filename": "n24q02m_wet-9.9.9.tar.gz",
    "url": "https://files.pythonhosted.org/p/n24q02m_wet-9.9.9.tar.gz",
    "digests": {"sha256": "a" * 64},
    "upload_time_iso_8601": "2026-01-01T00:00:00.000000Z",
}
WHEEL = {
    "packagetype": "bdist_wheel",
    "filename": "n24q02m_wet-9.9.9-py3-none-any.whl",
    "url": "https://files.pythonhosted.org/p/n24q02m_wet-9.9.9-py3-none-any.whl",
    "digests": {"sha256": "b" * 64},
    "upload_time_iso_8601": "2026-01-02T00:00:00.000000Z",
}

LOCK_BASE = "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/"

FORMULA = """class Wet < Formula
  desc "x"
  url "https://files.pythonhosted.org/p/n24q02m_wet-1.0.0-py3-none-any.whl", using: :nounzip
  sha256 "{old}"

  resource "lock" do
    url "{base}wet-1.0.0.txt"
    sha256 "{old}"
  end

  resource "build-lock" do
    url "{base}wet-1.0.0.build.txt"
    sha256 "{old}"
  end
end
""".format(old="0" * 64, base=LOCK_BASE)

MANIFEST = (
    json.dumps(
        {
            "version": "1.0.0",
            "url": [
                "old#/old.whl",
                LOCK_BASE + "wet-1.0.0.txt#/requirements.txt",
                LOCK_BASE + "wet-1.0.0.build.txt#/build-requirements.txt",
            ],
            "hash": ["0" * 64] * 3,
            "bin": "wet.exe",
        },
        indent=4,
    )
    + "\n"
)

NEW_LOCKS = {"wet-9.9.9.txt": "c" * 64, "wet-9.9.9.build.txt": "d" * 64}


def release(version="9.9.9"):
    return bump.Release(
        version,
        bump.Artifact("https://new/x.whl", "e" * 64),
        bump.Artifact("https://new/x.whl#/x.whl", "e" * 64),
        "2026-01-02T00:00:00Z",
    )


def tar_gz(files):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for name, body in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(body)
            tar.addfile(info, io.BytesIO(body))
    return buf.getvalue()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pypi_json(latest="9.9.9", files=(SDIST, WHEEL)):
    def get_json(url):
        if url.endswith("/n24q02m-wet/json"):
            return {"info": {"version": latest}}
        return {"urls": list(files)}

    return get_json


class ResolvePypi(unittest.TestCase):
    def test_latest_wheel_for_formula_and_manifest(self):
        rel = bump.resolve_pypi("n24q02m-wet", None, get_json=pypi_json())
        self.assertEqual(rel.version, "9.9.9")
        self.assertEqual(rel.formula, bump.Artifact(WHEEL["url"], "b" * 64))
        self.assertEqual(rel.manifest.url, WHEEL["url"] + "#/" + WHEEL["filename"])
        self.assertEqual(rel.manifest.sha256, "b" * 64)
        self.assertEqual(rel.published, WHEEL["upload_time_iso_8601"])

    def test_explicit_version_skips_latest_lookup(self):
        seen = []

        def get_json(url):
            seen.append(url)
            return {"urls": [SDIST, WHEEL]}

        bump.resolve_pypi("n24q02m-wet", "9.9.9", get_json=get_json)
        self.assertEqual(seen, ["https://pypi.org/pypi/n24q02m-wet/9.9.9/json"])

    def test_missing_wheel_fails(self):
        with self.assertRaises(SystemExit):
            bump.resolve_pypi("n24q02m-wet", None, get_json=pypi_json(files=(SDIST,)))


NPM_TARBALL = "https://registry.npmjs.org/@n24q02m/notion/-/notion-2.0.0.tgz"
NPM_DOC = {
    "dist-tags": {"latest": "2.0.0"},
    "versions": {
        "2.0.0": {"dist": {"tarball": NPM_TARBALL}},
        "1.0.0": {"dist": {"tarball": "old.tgz"}},
    },
    "time": {
        "2.0.0": "2026-02-02T00:00:00.000Z",
        "1.0.0": "2025-01-01T00:00:00.000Z",
    },
}


class ResolveNpm(unittest.TestCase):
    def test_sha256_is_computed_from_the_tarball(self):
        body = b"tarball-bytes"
        rel = bump.resolve_npm(
            "@n24q02m/notion", None, get_json=lambda _u: NPM_DOC, get=lambda _u: body
        )
        self.assertEqual(rel.version, "2.0.0")
        self.assertEqual(rel.formula, bump.Artifact(NPM_TARBALL, sha(body)))
        self.assertEqual(rel.formula, rel.manifest)
        self.assertEqual(rel.published, "2026-02-02T00:00:00.000Z")

    def test_explicit_version(self):
        rel = bump.resolve_npm(
            "@n24q02m/notion", "1.0.0", get_json=lambda _u: NPM_DOC, get=lambda _u: b""
        )
        self.assertEqual((rel.version, rel.formula.url), ("1.0.0", "old.tgz"))


class Resolve(unittest.TestCase):
    def test_prerelease_refused(self):
        with (
            mock.patch.object(bump, "resolve_pypi", return_value=release("1.0.0b1")),
            self.assertRaises(SystemExit),
        ):
            bump.resolve("wet", None)

    def test_npm_prerelease_refused(self):
        with (
            mock.patch.object(
                bump, "resolve_npm", return_value=release("1.0.0-beta.1")
            ),
            self.assertRaises(SystemExit),
        ):
            bump.resolve("notion", None)

    def test_stable_release_is_returned(self):
        rel = release("3.21.0")
        with mock.patch.object(bump, "resolve_pypi", return_value=rel) as pypi:
            self.assertIs(bump.resolve("wet", None), rel)
        pypi.assert_called_once_with("n24q02m-wet", None)


class Http(unittest.TestCase):
    def test_get_json_reads_the_response_body(self):
        resp = mock.MagicMock()
        resp.__enter__.return_value.read.return_value = b'{"ok": true}'
        with mock.patch.object(
            bump.urllib.request, "urlopen", return_value=resp
        ) as urlopen:
            self.assertEqual(bump._get_json("https://pypi.org/x"), {"ok": True})
        self.assertEqual(urlopen.call_args.args[0].full_url, "https://pypi.org/x")

    def test_transient_errors_are_retried(self):
        resp = mock.MagicMock()
        resp.__enter__.return_value.read.return_value = b"ok"
        flaky = [
            bump.urllib.error.URLError("EOF occurred in violation of protocol"),
            bump.urllib.error.HTTPError("https://pypi.org/x", 503, "busy", {}, None),
            resp,
        ]
        with (
            mock.patch.object(bump.urllib.request, "urlopen", side_effect=flaky),
            mock.patch.object(bump.time, "sleep") as sleep,
        ):
            self.assertEqual(bump._get("https://pypi.org/x"), b"ok")
        self.assertEqual(sleep.call_count, 2)

    def test_client_errors_are_not_retried(self):
        err = bump.urllib.error.HTTPError("https://pypi.org/x", 404, "gone", {}, None)
        with (
            mock.patch.object(bump.urllib.request, "urlopen", side_effect=err) as op,
            mock.patch.object(bump.time, "sleep"),
            self.assertRaises(bump.urllib.error.HTTPError),
        ):
            bump._get("https://pypi.org/x")
        self.assertEqual(op.call_count, 1)

    def test_retries_are_bounded(self):
        err = bump.urllib.error.URLError("down")
        with (
            mock.patch.object(bump.urllib.request, "urlopen", side_effect=err) as op,
            mock.patch.object(bump.time, "sleep"),
            self.assertRaises(bump.urllib.error.URLError),
        ):
            bump._get("https://pypi.org/x")
        self.assertEqual(op.call_count, bump.ATTEMPTS)


class Run(unittest.TestCase):
    def test_missing_executable_fails(self):
        with (
            mock.patch.object(bump.shutil, "which", return_value=None),
            self.assertRaises(SystemExit),
        ):
            bump._run(["uv", "export"])

    def test_runs_the_resolved_executable(self):
        done = mock.Mock(stdout="out")
        with (
            mock.patch.object(bump.shutil, "which", return_value="/bin/uv"),
            mock.patch.object(bump.subprocess, "run", return_value=done) as run,
        ):
            self.assertEqual(bump._run(["uv", "export"], cwd=Path(".")), "out")
        self.assertEqual(run.call_args.args[0], ["/bin/uv", "export"])
        self.assertEqual(run.call_args.kwargs["cwd"], Path("."))
        self.assertTrue(run.call_args.kwargs["check"])


class Markers(unittest.TestCase):
    def test_reachability(self):
        cases = {
            "sys_platform == 'unreachable'": False,
            "sys_platform == 'win32'": True,
            "platform_machine == 'x86_64' and sys_platform == 'linux'": True,
            "sys_platform != 'darwin' and sys_platform != 'win32' and sys_platform != 'linux'": False,
            "python_full_version < '3.14' or sys_platform == 'nope'": True,
            "sys_platform == 'nope' and python_full_version < '3.14'": False,
            "(sys_platform == 'nope' or os_name == 'x') and platform_machine == 'a'": False,
            "sys_platform == 'nope' or sys_platform == 'nope2'": False,
            "platform_system == 'Windows'": True,
            "android == 'x'": True,
        }
        for marker, want in cases.items():
            with self.subTest(marker=marker):
                self.assertIs(bump.marker_reachable(marker), want)

    def test_unparsable_markers_count_as_reachable(self):
        for marker in [
            "weird ~~ x",
            "(sys_platform == 'nope'",
            "sys_platform == 'nope')",
            "(",
            "sys_platform == 'nope' and",
        ]:
            with self.subTest(marker=marker):
                self.assertIsNone(bump._marker_value(marker, bump.PLATFORMS[0]))
                self.assertTrue(bump.marker_reachable(marker))

    def test_requirement_lines(self):
        text = (
            "a==1.0 \\\n    --hash=sha256:x\n"
            "b-c==2.0 ; sys_platform == 'win32' \\\n    --hash=sha256:y\n"
        )
        got = [m.groups() for m in bump.REQUIREMENT.finditer(text)]
        self.assertEqual(
            got, [("a", "1.0", None), ("b-c", "2.0", "sys_platform == 'win32'")]
        )


class LockNames(unittest.TestCase):
    def test_names_and_kinds(self):
        self.assertEqual(
            bump.lock_names("wet", "1.2"), ["wet-1.2.txt", "wet-1.2.build.txt"]
        )
        self.assertEqual(
            bump.lock_names("notion", "2.0"), ["notion-2.0.package-lock.json"]
        )
        self.assertEqual(bump.lock_kind("wet-1.2.build.txt"), ".build.txt")
        self.assertEqual(bump.lock_kind("wet-1.2.txt"), ".txt")
        self.assertEqual(
            bump.lock_kind("n-2.0.package-lock.json"), ".package-lock.json"
        )
        with self.assertRaises(SystemExit):
            bump.lock_kind("wet-1.2.whl")


class BuildRequires(unittest.TestCase):
    def test_declared_requires(self):
        data = tar_gz(
            {
                "p-1/pyproject.toml": b'[build-system]\nrequires = ["maturin>=1"]\n',
                "p-1/sub/pyproject.toml": b'[build-system]\nrequires = ["nope"]\n',
            }
        )
        self.assertEqual(bump.build_requires(data), ["maturin>=1"])

    def test_legacy_sdist_uses_setuptools(self):
        self.assertEqual(
            bump.build_requires(tar_gz({"p-1/setup.py": b""})),
            bump.DEFAULT_BUILD_REQUIRES,
        )
        self.assertEqual(
            bump.build_requires(tar_gz({"p-1/pyproject.toml": b"[tool.x]\n"})),
            bump.DEFAULT_BUILD_REQUIRES,
        )


PYAES = tar_gz({"pyaes-1.6.1/setup.py": b""})

UV_LOCK = """
[[package]]
name = "n24q02m-wet"
version = "9.9.9b1"
source = {{ editable = "." }}

[[package]]
name = "pyaes"
version = "1.6.1"
sdist = {{ url = "https://files/pyaes.tar.gz", hash = "sha256:{pyaes}" }}

[[package]]
name = "ghost"
version = "1.0"
sdist = {{ url = "https://files/ghost.tar.gz", hash = "sha256:{zero}" }}

[[package]]
name = "Wheel_Pkg"
version = "2.0"
wheels = [{{ url = "https://files/w.whl", hash = "sha256:{zero}" }}]
""".format(pyaes=sha(PYAES), zero="0" * 64)

EXPORT = (
    "ghost==1.0 ; sys_platform == 'unreachable' \\\n    --hash=sha256:0\n"
    "pyaes==1.6.1 \\\n    --hash=sha256:1\n"
    "wheel-pkg==2.0 \\\n    --hash=sha256:2\n"
)


class PythonLocks(unittest.TestCase):
    def fake(self, uv_lock=UV_LOCK, sdist=PYAES):
        calls = []

        def get(url):
            if url.endswith("pyproject.toml"):
                return b"[project]\n"
            if url.endswith("uv.lock"):
                return uv_lock.encode()
            return sdist

        def run(cmd, cwd=None):
            calls.append(cmd)
            if cmd[1] == "export":
                self.assertTrue((Path(cmd[-1]) / "uv.lock").is_file())
                return EXPORT
            self.assertEqual(
                Path(cmd[-1]).read_text(encoding="utf-8"), "setuptools>=40.8.0\n"
            )
            return "setuptools==1 \\\n    --hash=sha256:3\n"

        return get, run, calls

    def test_sdist_only_dependency_gets_a_hashed_backend(self):
        get, run, calls = self.fake()
        locks = bump.python_locks("wet", release(), get=get, run=run)
        self.assertEqual(sorted(locks), ["wet-9.9.9.build.txt", "wet-9.9.9.txt"])
        txt = locks["wet-9.9.9.txt"].decode()
        self.assertIn("--no-binary pyaes\n" + EXPORT, txt)
        self.assertNotIn("--no-binary ghost", txt)
        self.assertTrue(
            locks["wet-9.9.9.build.txt"]
            .decode()
            .endswith("setuptools==1 \\\n    --hash=sha256:3\n")
        )
        compile_cmd = calls[1]
        self.assertIn("--generate-hashes", compile_cmd)
        self.assertEqual(
            compile_cmd[compile_cmd.index("--exclude-newer") + 1],
            "2026-01-02T00:00:00Z",
        )

    def test_wheel_only_tree_has_an_empty_backend_lock(self):
        get, run, calls = self.fake(
            uv_lock=UV_LOCK.replace('name = "pyaes"', 'name = "other"')
        )
        locks = bump.python_locks("wet", release(), get=get, run=run)
        self.assertNotIn("--no-binary", locks["wet-9.9.9.txt"].decode())
        self.assertIn("# None:", locks["wet-9.9.9.build.txt"].decode())
        self.assertEqual(len(calls), 1)

    def test_lock_for_another_project_fails(self):
        get, run, _ = self.fake(uv_lock=UV_LOCK.replace("n24q02m-wet", "n24q02m-mnemo"))
        with self.assertRaises(SystemExit):
            bump.python_locks("wet", release(), get=get, run=run)

    def test_tampered_sdist_fails(self):
        get, run, _ = self.fake(sdist=b"tampered")
        with self.assertRaises(SystemExit):
            bump.python_locks("wet", release(), get=get, run=run)


class NpmLocks(unittest.TestCase):
    PKG = tar_gz({"package/package.json": b'{"name": "@n24q02m/notion"}'})

    def rel(self, digest):
        art = bump.Artifact("https://registry/notion-2.0.0.tgz", digest)
        return bump.Release("2.0.0", art, art, "2026-02-02T00:00:00.000Z")

    def test_lock_resolved_from_the_published_package_json(self):
        def run(cmd, cwd=None):
            self.assertEqual(
                (cwd / "package.json").read_bytes(), b'{"name": "@n24q02m/notion"}'
            )
            self.assertIn("--ignore-scripts", cmd)
            self.assertIn("--before=2026-02-02T00:00:00.000Z", cmd)
            (cwd / "package-lock.json").write_bytes(b"{}")
            return ""

        locks = bump.npm_locks(
            "notion", self.rel(sha(self.PKG)), get=lambda _u: self.PKG, run=run
        )
        self.assertEqual(locks, {"notion-2.0.0.package-lock.json": b"{}"})

    def test_changed_tarball_fails(self):
        with self.assertRaises(SystemExit):
            bump.npm_locks(
                "notion", self.rel("0" * 64), get=lambda _u: self.PKG, run=None
            )


class BuildLocks(unittest.TestCase):
    def test_dispatch_by_registry(self):
        with (
            mock.patch.object(bump, "python_locks", return_value={"p": b""}) as py,
            mock.patch.object(bump, "npm_locks", return_value={"n": b""}) as npm,
        ):
            self.assertEqual(bump.build_locks("wet", release()), {"p": b""})
            self.assertEqual(bump.build_locks("notion", release()), {"n": b""})
        py.assert_called_once()
        npm.assert_called_once()


class Rewrite(unittest.TestCase):
    ART = bump.Artifact("https://new/x.whl", "e" * 64)

    def test_formula_rewrites_artifact_and_locks(self):
        out = bump.rewrite_formula(FORMULA, self.ART, NEW_LOCKS)
        self.assertIn(
            '  url "https://new/x.whl", using: :nounzip\n  sha256 "' + "e" * 64, out
        )
        self.assertIn(
            f'    url "{LOCK_BASE}wet-9.9.9.txt"\n    sha256 "{"c" * 64}"', out
        )
        self.assertIn(
            f'    url "{LOCK_BASE}wet-9.9.9.build.txt"\n    sha256 "{"d" * 64}"', out
        )

    def test_formula_without_pair_fails(self):
        with self.assertRaises(SystemExit):
            bump.rewrite_formula("class X < Formula\nend\n", self.ART, NEW_LOCKS)

    def test_formula_missing_a_lock_resource_fails(self):
        with self.assertRaises(SystemExit):
            bump.rewrite_formula(
                FORMULA,
                self.ART,
                {**NEW_LOCKS, "wet-9.9.9.package-lock.json": "f" * 64},
            )

    def test_manifest_rewrites_artifact_and_locks(self):
        data = json.loads(bump.rewrite_manifest(MANIFEST, release(), NEW_LOCKS))
        self.assertEqual(
            data,
            {
                "version": "9.9.9",
                "url": [
                    "https://new/x.whl#/x.whl",
                    LOCK_BASE + "wet-9.9.9.txt#/requirements.txt",
                    LOCK_BASE + "wet-9.9.9.build.txt#/build-requirements.txt",
                ],
                "hash": ["e" * 64, "c" * 64, "d" * 64],
                "bin": "wet.exe",
            },
        )

    def test_manifest_needs_url_and_hash_lists(self):
        for bad in ({"url": "u", "hash": "h"}, {"url": ["u", "v"], "hash": ["h"]}):
            with self.subTest(bad=bad), self.assertRaises(SystemExit):
                bump.rewrite_manifest(json.dumps(bad), release(), NEW_LOCKS)


class WriteLocks(unittest.TestCase):
    def test_replaces_only_this_packages_old_locks(self):
        lock_dir = Path(tempfile.mkdtemp()) / "locks"
        lock_dir.mkdir()
        for name in (
            "wet-1.0.0.txt",
            "wet-1.0.0.build.txt",
            "wetter-1.0.txt",
            "mnemo-1.0.txt",
        ):
            (lock_dir / name).write_text("old", encoding="utf-8")
        bump.write_locks(
            lock_dir, "wet", {"wet-9.9.9.txt": b"a", "wet-9.9.9.build.txt": b"b"}
        )
        self.assertEqual(
            sorted(p.name for p in lock_dir.iterdir()),
            ["mnemo-1.0.txt", "wet-9.9.9.build.txt", "wet-9.9.9.txt", "wetter-1.0.txt"],
        )
        self.assertEqual((lock_dir / "wet-9.9.9.txt").read_bytes(), b"a")


MAIN_LOCKS = {"wet-9.9.9.txt": b"lock", "wet-9.9.9.build.txt": b"build"}


class Main(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "Formula").mkdir()
        (self.tmp / "bucket").mkdir()
        self.formula = self.tmp / "Formula" / "wet.rb"
        self.manifest = self.tmp / "bucket" / "wet.json"
        self.formula.write_text(FORMULA, encoding="utf-8")
        self.manifest.write_text(MANIFEST, encoding="utf-8")
        for target, value in (
            ("resolve", release()),
            ("build_locks", dict(MAIN_LOCKS)),
        ):
            patcher = mock.patch.object(bump, target, return_value=value)
            patcher.start()
            self.addCleanup(patcher.stop)
        env = mock.patch.dict(os.environ, {"GITHUB_OUTPUT": ""})
        env.start()
        self.addCleanup(env.stop)

    def run_main(self, *extra):
        return bump.main(
            [
                "wet",
                "--formula",
                str(self.formula),
                "--manifest",
                str(self.manifest),
                *extra,
            ]
        )

    def test_check_reports_missing_locks_without_writing(self):
        self.assertEqual(self.run_main("--check"), 1)
        self.assertEqual(self.formula.read_text(encoding="utf-8"), FORMULA)
        self.assertFalse((self.tmp / "locks").exists())

    def test_check_reports_drift_when_locks_exist(self):
        (self.tmp / "locks").mkdir()
        for name, body in MAIN_LOCKS.items():
            (self.tmp / "locks" / name).write_bytes(body)
        self.assertEqual(self.run_main("--check"), 1)
        self.assertEqual(self.formula.read_text(encoding="utf-8"), FORMULA)

    def test_write_then_check_is_clean(self):
        out = self.tmp / "github_output"
        with mock.patch.dict(os.environ, {"GITHUB_OUTPUT": str(out)}):
            self.assertEqual(self.run_main(), 0)
        self.assertEqual(out.read_text(encoding="utf-8"), "version=9.9.9\n")
        self.assertEqual((self.tmp / "locks" / "wet-9.9.9.txt").read_bytes(), b"lock")
        data = json.loads(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(data["hash"][1], sha(b"lock"))
        self.assertIn(sha(b"build"), self.formula.read_text(encoding="utf-8"))
        self.assertEqual(self.run_main("--check"), 0)
        self.assertEqual(self.run_main(), 0)

    def test_tampered_lock_fails_check(self):
        self.assertEqual(self.run_main(), 0)
        (self.tmp / "locks" / "wet-9.9.9.txt").write_bytes(b"tampered")
        self.assertEqual(self.run_main("--check"), 1)

    def test_formula_only(self):
        self.assertEqual(bump.main(["wet", "--formula", str(self.formula)]), 0)
        self.assertEqual(self.manifest.read_text(encoding="utf-8"), MANIFEST)

    def test_requires_a_target(self):
        with self.assertRaises(SystemExit):
            bump.main(["wet"])

    def test_pinned_resolves_the_named_release(self):
        self.assertEqual(self.run_main("--pinned", "--check"), 1)
        bump.resolve.assert_called_with("wet", "1.0.0")

    def test_pinned_needs_formula_and_manifest_to_agree(self):
        self.manifest.write_text(MANIFEST.replace("1.0.0", "2.0.0"), encoding="utf-8")
        with self.assertRaises(SystemExit):
            self.run_main("--pinned", "--check")

    def test_pinned_and_version_are_exclusive(self):
        with self.assertRaises(SystemExit):
            self.run_main("--pinned", "--version", "1.0.0")


class PinnedVersion(unittest.TestCase):
    def test_reads_the_version_from_lock_urls(self):
        self.assertEqual(bump.pinned_version("wet", FORMULA), "1.0.0")
        self.assertEqual(bump.pinned_version("wet", MANIFEST), "1.0.0")
        npm = '"' + LOCK_BASE + 'notion-2.43.0.package-lock.json#/package-lock.json"'
        self.assertEqual(bump.pinned_version("notion", npm), "2.43.0")

    def test_no_or_several_releases_fail(self):
        with self.assertRaises(SystemExit):
            bump.pinned_version("wet", "class Wet < Formula\nend\n")
        mixed = FORMULA.replace("wet-1.0.0.build.txt", "wet-1.0.1.build.txt")
        with self.assertRaises(SystemExit):
            bump.pinned_version("wet", mixed)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
