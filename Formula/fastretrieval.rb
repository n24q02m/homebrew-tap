class Fastretrieval < Formula
  desc "Multi-model retrieval runtime for ONNX and GGUF embeddings and reranking"
  homepage "https://github.com/n24q02m/fastretrieval"
  url "https://files.pythonhosted.org/packages/c5/23/d09a18d5955b1a100c5e2daf0ac02b4796ed8aaf5e7dc94acfaf49033e3b/fastretrieval-1.17.0-py3-none-any.whl", using: :nounzip
  sha256 "b2f2a1d2fcb259d3570b8e7885e4b0c1db4af93168fe5d7f84741004f3e7a6ef"
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
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/fastretrieval-1.17.0.txt"
    sha256 "7a2eee5c88839acafeb60192b6a861de54acf2191217e404b1d0d27819dd496a"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/fastretrieval-1.17.0.build.txt"
    sha256 "42232143451c7dc4781d29d9b0768ec47777b13c7c14ecc0c7445e7bfeeb8379"
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
