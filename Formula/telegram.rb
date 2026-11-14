class Telegram < Formula
  desc "Client and bot MCP server and CLI for Telegram"
  homepage "https://github.com/n24q02m/telegram"
  url "https://files.pythonhosted.org/packages/a2/43/1e4f120715b3a49874361fd804392e656e4152a1458528a61b109bb20f8f/n24q02m_telegram-4.24.0.tar.gz"
  sha256 "1a11e679a8be3cdebfdadab172fed3b8393ec46264caf7109a4afd52e17a7825"
  license "Apache-2.0"

  depends_on "python@3.13"

  def install
    # The sdist pins only this package; its dependencies resolve from PyPI into the
    # private virtualenv, the same set `pip install n24q02m-telegram` installs.
    system Formula["python@3.13"].opt_bin/"python3.13", "-m", "venv", libexec
    system libexec/"bin/python", "-m", "pip", "install", "--no-cache-dir", buildpath
    bin.install_symlink libexec/"bin/telegram"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/telegram --version")
  end
end
