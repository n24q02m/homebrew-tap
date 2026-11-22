class Telegram < Formula
  desc "Client and bot MCP server and CLI for Telegram"
  homepage "https://github.com/n24q02m/telegram"
  url "https://files.pythonhosted.org/packages/6a/bc/df35114e7ff37dd1a3dafd14ca007a06b14b6e745942b254050b232474e6/n24q02m_telegram-4.26.0-py3-none-any.whl", using: :nounzip
  sha256 "7fccaa503e37dd554df6c30f17a5ca0e41da5ec4f115211dfd3b983ca0ccf322"
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
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/telegram-4.26.0.txt"
    sha256 "1abe0c78fd171e151d3031f873076c38d06d873972ababf91e096663db8a5e4c"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/telegram-4.26.0.build.txt"
    sha256 "dcaa16ba2374d23febf2b16747be193afa490faaddd4f83019388c10c7c843f4"
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
