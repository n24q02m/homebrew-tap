class Wet < Formula
  desc "Streamable HTTP/stdio MCP server and CLI for web extraction and search"
  homepage "https://github.com/n24q02m/wet"
  url "https://files.pythonhosted.org/packages/91/a4/9be7e102f6c2ffa6fcb5fc109701a25afae640d3495420194c6546b59bb8/n24q02m_wet-3.22.0-py3-none-any.whl", using: :nounzip
  sha256 "8df66a9050d17447296ccd1d862baacfc2bec9de22a279e759cd648d1aea8c9d"
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
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/wet-3.22.0.txt"
    sha256 "7f422c15a99f57b7df5131c155c1a63d4ac2a708c684beed4445117fd7bacb39"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/wet-3.22.0.build.txt"
    sha256 "44d80d94e3978e215730c6f8333bcb2610ecd5aa15976d482c2eaa64e069429b"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"wet/venv"
    bin.write_exec_script venv/"bin/wet"
  end

  # The environment lives outside the keg: prebuilt native extensions in the dependency
  # tree leave no Mach-O header room for keg relocation. The lock already is the release's
  # resolved environment (including its uv overrides), so there is no `uv pip check`.
  post_install_steps do
    remove "{{var}}/wet/venv", recursive: true
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["venv", "--quiet", "--python", "{{HOMEBREW_PREFIX}}/opt/python@3.13/bin/python3.13",
               "{{var}}/wet/venv"],
        env:  { "UV_PYTHON_DOWNLOADS" => "never" }
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/wet/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "-r", "{{libexec}}/build-requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/wet/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "--no-build-isolation",
               "-r", "{{libexec}}/requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/wet/venv/bin/python", "--no-deps", "--no-index",
               "--quiet", "--find-links", "{{libexec}}", "n24q02m-wet=={{version}}"]
  end

  def caveats
    <<~EOS
      wet runs from a Python environment in #{var}/wet/venv, rebuilt on each install
      or upgrade. `brew uninstall wet` leaves it; delete that directory to reclaim space.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wet --version")
  end
end
