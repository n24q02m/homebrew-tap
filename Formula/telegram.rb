class Telegram < Formula
  desc "Client and bot MCP server and CLI for Telegram"
  homepage "https://github.com/n24q02m/telegram"
  url "https://files.pythonhosted.org/packages/d6/3b/cd1cdd93a7dd2804513c228c00252d1314b43c61bdbbd259e8db66261bb8/n24q02m_telegram-4.26.1-py3-none-any.whl", using: :nounzip
  sha256 "1f4395fa17259832f439a8e59acb6990afd1567f62a1732c192bbdd763a55fb1"
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
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/telegram-4.26.1.txt"
    sha256 "e6410cc2cb62e43dd561226798e2b6627b46a0ef29b44f47e02111a6cf68d4a6"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/telegram-4.26.1.build.txt"
    sha256 "7f0d298d5226b3f3eb8221bbb122187eddc4ad3e1b81b3b80b2473e71a0750fe"
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
