class Wet < Formula
  desc "Streamable HTTP/stdio MCP server and CLI for web extraction and search"
  homepage "https://github.com/n24q02m/wet"
  url "https://files.pythonhosted.org/packages/31/0b/056960e573555060d079c4ee54b8cda11ee2230127cd18d94516d5891cc5/n24q02m_wet-3.21.0-py3-none-any.whl", using: :nounzip
  sha256 "c53f5422abc195483b14a77f00a77640d12083b60ef58b8b0fd6872a49483f25"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  def install
    # The dependency tree ships prebuilt native extensions whose Mach-O headers have no
    # room for keg relocation, so the keg keeps only the release wheel and uv builds its
    # environment in the uv cache on first run, the same one `uvx --from n24q02m-wet` uses.
    libexec.install Dir["*.whl"]
    wheel = libexec.glob("*.whl").first
    python = formula_opt_bin("python@3.13")/"python3.13"
    uv = formula_opt_bin("uv")/"uv"
    env = { UV_PYTHON_DOWNLOADS: "never" }
    (bin/"wet").write_env_script uv, "tool run --python #{python} --from #{wheel} wet", env
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wet --version")
  end
end
