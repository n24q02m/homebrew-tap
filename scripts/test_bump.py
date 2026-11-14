"""Offline tests for bump.py: registry lookups are replaced by fixed payloads."""

import hashlib
import json
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
}
WHEEL = {
    "packagetype": "bdist_wheel",
    "filename": "n24q02m_wet-9.9.9-py3-none-any.whl",
    "url": "https://files.pythonhosted.org/p/n24q02m_wet-9.9.9-py3-none-any.whl",
    "digests": {"sha256": "b" * 64},
}

FORMULA = """class Wet < Formula
  desc "x"
  url "https://files.pythonhosted.org/p/n24q02m_wet-1.0.0.tar.gz"
  sha256 "{old}"

  resource "inner" do
    url "https://example.invalid/inner.tar.gz"
    sha256 "{old}"
  end
end
""".format(old="0" * 64)

MANIFEST = (
    json.dumps(
        {"version": "1.0.0", "url": "old", "hash": "0" * 64, "bin": "wet.exe"}, indent=4
    )
    + "\n"
)


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


class ResolveNpm(unittest.TestCase):
    def test_sha256_is_computed_from_the_tarball(self):
        body = b"tarball-bytes"

        def get_json(url):
            if url == "https://registry.npmjs.org/@n24q02m/notion":
                return {"dist-tags": {"latest": "2.0.0"}}
            return {
                "dist": {
                    "tarball": "https://registry.npmjs.org/@n24q02m/notion/-/notion-2.0.0.tgz"
                }
            }

        rel = bump.resolve_npm(
            "@n24q02m/notion", None, get_json=get_json, get=lambda _u: body
        )
        self.assertEqual(rel.version, "2.0.0")
        self.assertEqual(rel.formula.sha256, hashlib.sha256(body).hexdigest())
        self.assertEqual(rel.formula, rel.manifest)


class Resolve(unittest.TestCase):
    def test_prerelease_refused(self):
        rel = bump.Release("1.0.0b1", bump.Artifact("u", "a"), bump.Artifact("u", "a"))
        with (
            mock.patch.object(bump, "resolve_pypi", return_value=rel),
            self.assertRaises(SystemExit),
        ):
            bump.resolve("wet", None)

    def test_npm_prerelease_refused(self):
        rel = bump.Release(
            "1.0.0-beta.1", bump.Artifact("u", "a"), bump.Artifact("u", "a")
        )
        with (
            mock.patch.object(bump, "resolve_npm", return_value=rel),
            self.assertRaises(SystemExit),
        ):
            bump.resolve("notion", None)


class Http(unittest.TestCase):
    def test_get_json_reads_the_response_body(self):
        resp = mock.MagicMock()
        resp.__enter__.return_value.read.return_value = b'{"ok": true}'
        with mock.patch.object(
            bump.urllib.request, "urlopen", return_value=resp
        ) as urlopen:
            self.assertEqual(bump._get_json("https://pypi.org/x"), {"ok": True})
        self.assertEqual(urlopen.call_args.args[0].full_url, "https://pypi.org/x")


class ResolveStable(unittest.TestCase):
    def test_stable_release_is_returned(self):
        rel = bump.Release("3.21.0", bump.Artifact("u", "a"), bump.Artifact("u", "a"))
        with mock.patch.object(bump, "resolve_pypi", return_value=rel) as pypi:
            self.assertIs(bump.resolve("wet", None), rel)
        pypi.assert_called_once_with("n24q02m-wet", None)


class Rewrite(unittest.TestCase):
    def test_formula_rewrites_only_top_level_pair(self):
        out = bump.rewrite_formula(
            FORMULA, bump.Artifact("https://new/x.tar.gz", "c" * 64)
        )
        self.assertIn('  url "https://new/x.tar.gz"\n  sha256 "' + "c" * 64, out)
        self.assertIn(
            '    url "https://example.invalid/inner.tar.gz"\n    sha256 "' + "0" * 64,
            out,
        )

    def test_formula_keeps_url_options(self):
        text = FORMULA.replace('.tar.gz"\n', '.whl", using: :nounzip\n', 1)
        out = bump.rewrite_formula(text, bump.Artifact("https://new/x.whl", "c" * 64))
        self.assertIn('  url "https://new/x.whl", using: :nounzip\n', out)

    def test_formula_without_pair_fails(self):
        with self.assertRaises(SystemExit):
            bump.rewrite_formula(
                "class X < Formula\nend\n", bump.Artifact("u", "c" * 64)
            )

    def test_manifest_keeps_other_keys(self):
        rel = bump.Release(
            "9.9.9", bump.Artifact("f", "a" * 64), bump.Artifact("m#/w.whl", "b" * 64)
        )
        data = json.loads(bump.rewrite_manifest(MANIFEST, rel))
        self.assertEqual(
            data,
            {"version": "9.9.9", "url": "m#/w.whl", "hash": "b" * 64, "bin": "wet.exe"},
        )


class Main(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.formula = self.tmp / "wet.rb"
        self.manifest = self.tmp / "wet.json"
        self.formula.write_text(FORMULA, encoding="utf-8")
        self.manifest.write_text(MANIFEST, encoding="utf-8")
        rel = bump.Release(
            "9.9.9",
            bump.Artifact("https://new/x.tar.gz", "c" * 64),
            bump.Artifact("m", "d" * 64),
        )
        patcher = mock.patch.object(bump, "resolve", return_value=rel)
        patcher.start()
        self.addCleanup(patcher.stop)

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

    def test_check_reports_drift_without_writing(self):
        self.assertEqual(self.run_main("--check"), 1)
        self.assertEqual(self.formula.read_text(encoding="utf-8"), FORMULA)

    def test_write_then_check_is_clean(self):
        self.assertEqual(self.run_main(), 0)
        self.assertEqual(
            json.loads(self.manifest.read_text(encoding="utf-8"))["version"], "9.9.9"
        )
        self.assertEqual(self.run_main("--check"), 0)

    def test_formula_only(self):
        self.assertEqual(bump.main(["wet", "--formula", str(self.formula)]), 0)
        self.assertEqual(self.manifest.read_text(encoding="utf-8"), MANIFEST)

    def test_requires_a_target(self):
        with self.assertRaises(SystemExit):
            bump.main(["wet"])


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
