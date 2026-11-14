class Crg < Formula
  desc "Code review and AST symbol graph MCP server and CLI"
  homepage "https://github.com/n24q02m/crg"
  url "https://files.pythonhosted.org/packages/01/83/fa3d848a0cd610a61dfde6a069e9a8e79d25d2d972958c5e66fc6f8d22c4/n24q02m_crg-3.32.0-py3-none-any.whl", using: :nounzip
  sha256 "7f166adefb812d2474a5e4a85ed725bc4ea78d1d25c7b3f0165ef09f9b0dcbb4"
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
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/crg-3.32.0.txt"
    sha256 "1fdb24c34222c1d9331582d6a14b0431cfd1a2c4a8809e923fef094d6dbf539d"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/crg-3.32.0.build.txt"
    sha256 "76fbf7aecbbb158007c04c72bff048593d7fae676700dc5d72bc4a7af3cedda8"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"crg/venv"
    bin.write_exec_script venv/"bin/crg"
  end

  def post_install
    # The environment lives outside the keg: prebuilt native extensions in the dependency
    # tree leave no Mach-O header room for keg relocation.
    venv = var/"crg/venv"
    rm_r venv if venv.exist?
    ENV["UV_PYTHON_DOWNLOADS"] = "never"
    uv = formula_opt_bin("uv")/"uv"
    python = venv/"bin/python"
    system uv, "venv", "--quiet", "--python", formula_opt_bin("python@3.13")/"python3.13", venv
    pinned = %W[--python #{python} --require-hashes --only-binary :all: --no-deps --quiet]
    system uv, "pip", "install", *pinned, "-r", libexec/"build-requirements.txt"
    system uv, "pip", "install", *pinned, "--no-build-isolation", "-r", libexec/"requirements.txt"
    system uv, "pip", "install", "--python", python, "--no-deps", "--quiet", *libexec.glob("*.whl")
    system uv, "pip", "check", "--python", python
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
