class Crg < Formula
  desc "Code review and AST symbol graph MCP server and CLI"
  homepage "https://github.com/n24q02m/crg"
  url "https://files.pythonhosted.org/packages/5a/b2/bae1fb3db752f7e34aa7068ed82cdcfcecbfd9915461cb6c6761edc939a9/n24q02m_crg-3.36.0-py3-none-any.whl", using: :nounzip
  sha256 "2040bbeea7d8dac4d25918df5fe4220ea19a2501c6d223c37b0c64c4be1625d9"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  on_macos do
    # onnxruntime has no Intel macOS wheel; tree-sitter-language-pack needs macOS 15.
    depends_on arch: :arm64
    depends_on macos: :sequoia
  end

  # Every dependency is pinned by hash: `lock` is the release tag's uv.lock exported as
  # requirements, `build-lock` the build backends of dependencies that publish only an
  # sdist. scripts/bump.py regenerates both on each bump.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/crg-3.36.0.txt"
    sha256 "6fd8e25baf0af586aad78114c5952e85195d89faddb29c78eeb5204998ebe826"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/crg-3.36.0.build.txt"
    sha256 "98a63c09402db454d7143dc14b7f1c8de78dc83a96a888e5a443d0693a5084d2"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"crg/venv"
    bin.write_exec_script venv/"bin/crg"
  end

  # The environment lives outside the keg: prebuilt native extensions in the dependency
  # tree leave no Mach-O header room for keg relocation. The lock already is the release's
  # resolved environment (including its uv overrides), so there is no `uv pip check`.
  post_install_steps do
    remove "{{var}}/crg/venv", recursive: true
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["venv", "--quiet", "--python", "{{HOMEBREW_PREFIX}}/opt/python@3.13/bin/python3.13",
               "{{var}}/crg/venv"],
        env:  { "UV_PYTHON_DOWNLOADS" => "never" }
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/crg/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "-r", "{{libexec}}/build-requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/crg/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "--no-build-isolation",
               "-r", "{{libexec}}/requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/crg/venv/bin/python", "--no-deps", "--no-index",
               "--quiet", "--find-links", "{{libexec}}", "n24q02m-crg=={{version}}"]
  end

  def caveats
    <<~EOS
      crg runs from a Python environment in #{var}/crg/venv, rebuilt on each install
      or upgrade. `brew uninstall crg` leaves it; delete that directory to reclaim space.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/crg --version")
  end
end
