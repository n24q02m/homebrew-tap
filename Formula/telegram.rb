class Telegram < Formula
  desc "Client and bot MCP server and CLI for Telegram"
  homepage "https://github.com/n24q02m/telegram"
  url "https://files.pythonhosted.org/packages/bc/67/9d1b82932bd6371a6a8e6c9abcaf5f9fdf2deb8beaab83630ebefa0ef72a/n24q02m_telegram-4.27.0-py3-none-any.whl", using: :nounzip
  sha256 "0345892795ac7d946276d829f3b42e3c1051c7d47b685e62f19ddeffd82aa3cc"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  on_macos do
    # cryptg and cryptography publish no Intel macOS wheels for this release.
    depends_on arch: :arm64
  end

  # Every dependency is pinned by hash: `lock` is the release tag's uv.lock exported as
  # requirements, `build-lock` the build backends of dependencies that publish only an
  # sdist. scripts/bump.py regenerates both on each bump.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/telegram-4.27.0.txt"
    sha256 "6d91926cc1088cc0e63f404589169f0e5618c5d08318060e807e2f5ce56c42ee"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/telegram-4.27.0.build.txt"
    sha256 "8fca0a5e3959bdb78792514a44be62797d14488fcf61fc7cb0ea4d5f72189a49"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"telegram/venv"
    bin.write_exec_script venv/"bin/telegram"
  end

  # The environment lives outside the keg: prebuilt native extensions in the dependency
  # tree leave no Mach-O header room for keg relocation. The lock already is the release's
  # resolved environment (including its uv overrides), so there is no `uv pip check`.
  post_install_steps do
    remove "{{var}}/telegram/venv", recursive: true
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["venv", "--quiet", "--python", "{{HOMEBREW_PREFIX}}/opt/python@3.13/bin/python3.13",
               "{{var}}/telegram/venv"],
        env:  { "UV_PYTHON_DOWNLOADS" => "never" }
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/telegram/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "-r", "{{libexec}}/build-requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/telegram/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "--no-build-isolation",
               "-r", "{{libexec}}/requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/telegram/venv/bin/python", "--no-deps", "--no-index",
               "--quiet", "--find-links", "{{libexec}}", "n24q02m-telegram=={{version}}"]
  end

  def caveats
    <<~EOS
      telegram runs from a Python environment in #{var}/telegram/venv, rebuilt on each install
      or upgrade. `brew uninstall telegram` leaves it; delete that directory to reclaim space.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/telegram --version")
  end
end
