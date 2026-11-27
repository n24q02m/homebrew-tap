class Bsr < Formula
  desc "Drop-in python-semantic-release fork with built-in release-safety guards"
  homepage "https://github.com/n24q02m/better-semantic-release"
  url "https://files.pythonhosted.org/packages/77/a4/20862736faa5aa7c7616a8a2b6df52e340e73933c8438570bee1a3ca8afd/better_semantic_release-1.14.1-py3-none-any.whl", using: :nounzip
  sha256 "4e1271eb542aee82593141cbc12eb4aff95e8f47cda3e4bfb466ad02d6314e22"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  # Every dependency is pinned by hash: `lock` is the release tag's uv.lock exported as
  # requirements, `build-lock` the build backends of dependencies that publish only an
  # sdist. scripts/bump.py regenerates both on each bump.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/bsr-1.14.1.txt"
    sha256 "bb33ac221b128bc27fb43ca46f77ab70b796578e3d5a8f18f9c085adb13e6ea6"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/bsr-1.14.1.build.txt"
    sha256 "e12784b4859ab8f807c125c5796092b914c50251c170dd2c59b613ace55e0aa8"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"bsr/venv"
    bin.write_exec_script venv/"bin/bsr"
  end

  # The environment lives outside the keg: prebuilt native extensions in the dependency
  # tree leave no Mach-O header room for keg relocation. The lock already is the release's
  # resolved environment (including its uv overrides), so there is no `uv pip check`.
  post_install_steps do
    remove "{{var}}/bsr/venv", recursive: true
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["venv", "--quiet", "--python", "{{HOMEBREW_PREFIX}}/opt/python@3.13/bin/python3.13",
               "{{var}}/bsr/venv"],
        env:  { "UV_PYTHON_DOWNLOADS" => "never" }
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/bsr/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "-r", "{{libexec}}/build-requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/bsr/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "--no-build-isolation",
               "-r", "{{libexec}}/requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/bsr/venv/bin/python", "--no-deps", "--no-index",
               "--quiet", "--find-links", "{{libexec}}", "better-semantic-release=={{version}}"]
  end

  def caveats
    <<~EOS
      bsr runs from a Python environment in #{var}/bsr/venv, rebuilt on each install
      or upgrade. `brew uninstall bsr` leaves it; delete that directory to reclaim space.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bsr --version")
  end
end
