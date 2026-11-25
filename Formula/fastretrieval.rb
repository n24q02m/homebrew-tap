class Fastretrieval < Formula
  desc "Multi-model retrieval runtime for ONNX and GGUF embeddings and reranking"
  homepage "https://github.com/n24q02m/fastretrieval"
  url "https://files.pythonhosted.org/packages/f1/1b/8a1b10c24a2d61af8d5f94791cf5aaace924f26f7aaa7f2f0128502869c1/fastretrieval-1.16.0-py3-none-any.whl", using: :nounzip
  sha256 "4729ad3ef6fb087258e48d4fea4091ae69bbcac876da06711e4414105abcb092"
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
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/fastretrieval-1.16.0.txt"
    sha256 "80a097724634c6fb1bdc99cfc0110b13ca92612f34336b492af3464772f37ec8"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/fastretrieval-1.16.0.build.txt"
    sha256 "3b55c1e0bf042180847028148bcb5e23f3e9a9e8ab4f5c8ec4d10d1ffacee21f"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"fastretrieval/venv"
    bin.write_exec_script venv/"bin/fastretrieval-server"
  end

  # The environment lives outside the keg: prebuilt native extensions in the dependency
  # tree leave no Mach-O header room for keg relocation. The lock already is the release's
  # resolved environment (including its uv overrides), so there is no `uv pip check`.
  post_install_steps do
    remove "{{var}}/fastretrieval/venv", recursive: true
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["venv", "--quiet", "--python", "{{HOMEBREW_PREFIX}}/opt/python@3.13/bin/python3.13",
               "{{var}}/fastretrieval/venv"],
        env:  { "UV_PYTHON_DOWNLOADS" => "never" }
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/fastretrieval/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "-r", "{{libexec}}/build-requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/fastretrieval/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "--no-build-isolation",
               "-r", "{{libexec}}/requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/fastretrieval/venv/bin/python", "--no-deps", "--no-index",
               "--quiet", "--find-links", "{{libexec}}", "fastretrieval=={{version}}"]
  end

  def caveats
    <<~EOS
      fastretrieval-server runs from a Python environment in #{var}/fastretrieval/venv, rebuilt on each install
      or upgrade. `brew uninstall fastretrieval` leaves it; delete that directory to reclaim space.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/fastretrieval-server --version")
  end
end
