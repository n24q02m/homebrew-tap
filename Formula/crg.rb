class Crg < Formula
  desc "Code review and AST symbol graph MCP server and CLI"
  homepage "https://github.com/n24q02m/crg"
  url "https://files.pythonhosted.org/packages/01/83/fa3d848a0cd610a61dfde6a069e9a8e79d25d2d972958c5e66fc6f8d22c4/n24q02m_crg-3.32.0-py3-none-any.whl", using: :nounzip
  sha256 "7f166adefb812d2474a5e4a85ed725bc4ea78d1d25c7b3f0165ef09f9b0dcbb4"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  def install
    # The dependency tree ships prebuilt native extensions whose Mach-O headers have no
    # room for keg relocation, so the keg keeps only the release wheel and uv builds its
    # environment in the uv cache on first run, the same one `uvx --from n24q02m-crg` uses.
    libexec.install Dir["*.whl"]
    wheel = libexec.glob("*.whl").first
    python = formula_opt_bin("python@3.13")/"python3.13"
    uv = formula_opt_bin("uv")/"uv"
    env = { UV_PYTHON_DOWNLOADS: "never" }
    (bin/"crg").write_env_script uv, "tool run --python #{python} --from #{wheel} crg", env
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/crg --version")
  end
end
