class Telegram < Formula
  desc "Client and bot MCP server and CLI for Telegram"
  homepage "https://github.com/n24q02m/telegram"
  url "https://files.pythonhosted.org/packages/c7/d8/63ea18bee72926ffa1521f778dd2f10dd3bdb74c47128b7a1d7ea017832d/n24q02m_telegram-4.24.0-py3-none-any.whl", using: :nounzip
  sha256 "37a0535ca80377b2fcec9fb2040e3dced911e80994ea3b59270fad13fd83eaf1"
  license "Apache-2.0"

  depends_on "python@3.13"
  depends_on "uv"

  def install
    # The dependency tree ships prebuilt native extensions whose Mach-O headers have no
    # room for keg relocation, so the keg keeps only the release wheel and uv builds its
    # environment in the uv cache on first run, the same one `uvx --from n24q02m-telegram` uses.
    libexec.install Dir["*.whl"]
    wheel = libexec.glob("*.whl").first
    python = formula_opt_bin("python@3.13")/"python3.13"
    uv = formula_opt_bin("uv")/"uv"
    env = { UV_PYTHON_DOWNLOADS: "never" }
    (bin/"telegram").write_env_script uv, "tool run --python #{python} --from #{wheel} telegram", env
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/telegram --version")
  end
end
