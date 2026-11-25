class Mnemo < Formula
  desc "Episodic and semantic memory MCP server and CLI"
  homepage "https://github.com/n24q02m/mnemo"
  url "https://files.pythonhosted.org/packages/f4/24/fe3d0e7f72c2a6cc95c5bee7e6bde16e572e55a7907f794d5c834525a8e9/n24q02m_mnemo-2.25.0-py3-none-any.whl", using: :nounzip
  sha256 "4c06623950ff4b361fb42e4d0964f07d7030b008de40f6260595357b47a071ce"
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
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/mnemo-2.25.0.txt"
    sha256 "6ec305e36aed6e5b3afaa95a5cb085130321e12f5b339918c8fa49f9c921c1a8"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/mnemo-2.25.0.build.txt"
    sha256 "3404e4812ce7e919be32637ca87b1e7a47b7e2633acb16e99601c3d0b5a9ffe0"
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
