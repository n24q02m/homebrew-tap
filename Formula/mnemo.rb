class Mnemo < Formula
  desc "Episodic and semantic memory MCP server and CLI"
  homepage "https://github.com/n24q02m/mnemo"
  url "https://files.pythonhosted.org/packages/95/71/0b6ffcb758e19ee21548ade024aa21883c444fad5c200bad4a8f5bc1a5ea/n24q02m_mnemo-2.22.0-py3-none-any.whl", using: :nounzip
  sha256 "136862dc1f010c46e74c6cd3b7a8461e501a466fad9a71a68257c2cfe488b7fc"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  on_macos do
    # onnxruntime publishes macOS wheels for arm64 on macOS 14 or later only.
    depends_on arch: :arm64
    depends_on macos: :sonoma
  end

  # Every dependency is pinned by hash: `lock` is the release tag's uv.lock exported as
  # requirements, `build-lock` the build backends of dependencies that publish only an
  # sdist. scripts/bump.py regenerates both on each bump.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/mnemo-2.22.0.txt"
    sha256 "c27bc756c8434e44130bd2dd47b41246412f5b7977268e85cbed11867b7d7726"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/mnemo-2.22.0.build.txt"
    sha256 "d385249d54d11125a6ff215710cc25e1fdfcee5e3cd81cb869f465dc0437ce89"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"mnemo/venv"
    bin.write_exec_script venv/"bin/mnemo", venv/"bin/n24q02m-mnemo"
  end

  # The environment lives outside the keg: prebuilt native extensions in the dependency
  # tree leave no Mach-O header room for keg relocation. The lock already is the release's
  # resolved environment (including its uv overrides), so there is no `uv pip check`.
  post_install_steps do
    remove "{{var}}/mnemo/venv", recursive: true
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["venv", "--quiet", "--python", "{{HOMEBREW_PREFIX}}/opt/python@3.13/bin/python3.13",
               "{{var}}/mnemo/venv"],
        env:  { "UV_PYTHON_DOWNLOADS" => "never" }
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/mnemo/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "-r", "{{libexec}}/build-requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/mnemo/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "--no-build-isolation",
               "-r", "{{libexec}}/requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/mnemo/venv/bin/python", "--no-deps", "--no-index",
               "--quiet", "--find-links", "{{libexec}}", "n24q02m-mnemo=={{version}}"]
  end

  def caveats
    <<~EOS
      mnemo runs from a Python environment in #{var}/mnemo/venv, rebuilt on each install
      or upgrade. `brew uninstall mnemo` leaves it; delete that directory to reclaim space.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/n24q02m-mnemo --version")
  end
end
