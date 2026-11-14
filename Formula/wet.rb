class Wet < Formula
  desc "Streamable HTTP/stdio MCP server and CLI for web extraction and search"
  homepage "https://github.com/n24q02m/wet"
  url "https://files.pythonhosted.org/packages/65/34/129c50681cd78c239d1843170ff07b26457f10f4b19b24eb1c0a0ccb22a3/n24q02m_wet-3.21.0.tar.gz"
  sha256 "d46bd1580d2cc9effa6658d80cc490a4f69dc4d13df0a1cedeaf432db2f27d65"
  license "Apache-2.0"

  depends_on "python@3.13"

  def install
    # The sdist pins only this package; its dependencies resolve from PyPI into the
    # private virtualenv, the same set `pip install n24q02m-wet` installs.
    system Formula["python@3.13"].opt_bin/"python3.13", "-m", "venv", libexec
    system libexec/"bin/python", "-m", "pip", "install", "--no-cache-dir", buildpath
    bin.install_symlink libexec/"bin/wet"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/wet --version")
  end
end
