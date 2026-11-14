class Crg < Formula
  desc "Code review and AST symbol graph MCP server and CLI"
  homepage "https://github.com/n24q02m/crg"
  url "https://files.pythonhosted.org/packages/c6/79/fb26a637567cb4b08906d8cb2867af7ac8b3ae81c7351c355ae473ab38c6/n24q02m_crg-3.32.0.tar.gz"
  sha256 "7d60800668897b8a0e7b0320a26bc40664f27ca476884b6355f6194b4cf02f55"
  license "Apache-2.0"

  depends_on "python@3.13"

  def install
    # The sdist pins only this package; its dependencies resolve from PyPI into the
    # private virtualenv, the same set `pip install n24q02m-crg` installs.
    system Formula["python@3.13"].opt_bin/"python3.13", "-m", "venv", libexec
    system libexec/"bin/python", "-m", "pip", "install", "--no-cache-dir", buildpath
    bin.install_symlink libexec/"bin/crg"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/crg --version")
  end
end
