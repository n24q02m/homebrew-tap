class Bsr < Formula
  desc "Drop-in python-semantic-release fork with built-in release-safety guards"
  homepage "https://github.com/n24q02m/better-semantic-release"
  url "https://files.pythonhosted.org/packages/9e/b5/61000ffe48be26095593ec5ae961990050c360a8ac6fad50be26c2462cc3/better_semantic_release-1.14.0-py3-none-any.whl", using: :nounzip
  sha256 "a868dac0c302461930001da77aaf545c3c11c734ae05ed4500d49a8bd807b94e"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  # Every dependency is pinned by hash: `lock` is the release tag's uv.lock exported as
  # requirements, `build-lock` the build backends of dependencies that publish only an
  # sdist. scripts/bump.py regenerates both on each bump.
  resource "lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/bsr-1.14.0.txt"
    sha256 "c220ab319c867b8fd29fee4d40f02e40835f3966a00851724c8dc05d5eccc131"
  end

  resource "build-lock" do
    url "https://raw.githubusercontent.com/n24q02m/homebrew-tap/main/locks/bsr-1.14.0.build.txt"
    sha256 "f193f64dc4de7e5fcc03abe7574164bea635b6dc6e29276978c5767ff45d7f4d"
  end

  def install
    libexec.install Dir["*.whl"]
    resource("lock").stage { libexec.install Dir["*.txt"].first => "requirements.txt" }
    resource("build-lock").stage { libexec.install Dir["*.txt"].first => "build-requirements.txt" }
    venv = var/"bsr/venv"
    bin.write_exec_script venv/"bin/bsr"
  end

  # The environment lives outside the keg: prebuilt native extensions in the dependency
  # tree leave no Mach-O header room for keg relocation. The lock already is the release's
  # resolved environment (including its uv overrides), so there is no `uv pip check`.
  post_install_steps do
    remove "{{var}}/bsr/venv", recursive: true
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["venv", "--quiet", "--python", "{{HOMEBREW_PREFIX}}/opt/python@3.13/bin/python3.13",
               "{{var}}/bsr/venv"],
        env:  { "UV_PYTHON_DOWNLOADS" => "never" }
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/bsr/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "-r", "{{libexec}}/build-requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/bsr/venv/bin/python", "--require-hashes",
               "--only-binary", ":all:", "--no-deps", "--quiet", "--no-build-isolation",
               "-r", "{{libexec}}/requirements.txt"]
    run "{{HOMEBREW_PREFIX}}/opt/uv/bin/uv",
        args: ["pip", "install", "--python", "{{var}}/bsr/venv/bin/python", "--no-deps", "--no-index",
               "--quiet", "--find-links", "{{libexec}}", "better-semantic-release=={{version}}"]
  end

  def caveats
    <<~EOS
      bsr runs from a Python environment in #{var}/bsr/venv, rebuilt on each install
      or upgrade. `brew uninstall bsr` leaves it; delete that directory to reclaim space.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bsr --version")
  end
end
