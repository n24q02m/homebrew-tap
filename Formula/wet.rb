class Wet < Formula
  desc "Streamable HTTP/stdio MCP server and CLI for web extraction and search"
  homepage "https://github.com/n24q02m/wet"
  url "https://files.pythonhosted.org/packages/31/0b/056960e573555060d079c4ee54b8cda11ee2230127cd18d94516d5891cc5/n24q02m_wet-3.21.0-py3-none-any.whl", using: :nounzip
  sha256 "c53f5422abc195483b14a77f00a77640d12083b60ef58b8b0fd6872a49483f25"
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
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/wet-3.21.0.txt"
    sha256 "ff40ad8c2e31d6e9babd763fa4bd641346133a545c55468cf8189d2a4518df8a"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/wet-3.21.0.build.txt"
    sha256 "346bd8eee0d6e79ad48e8326d70823e0c8c316ed8dd756e5496a3693b6186244"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"wet/venv"
    bin.write_exec_script venv/"bin/wet"
  end

  def post_install
    # The environment lives outside the keg: prebuilt native extensions in the dependency
    # tree leave no Mach-O header room for keg relocation.
    venv = var/"wet/venv"
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
      wet runs from a Python environment in #{var}/wet/venv, rebuilt on each install
      or upgrade. `brew uninstall wet` leaves it; delete that directory to reclaim space.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wet --version")
  end
end
