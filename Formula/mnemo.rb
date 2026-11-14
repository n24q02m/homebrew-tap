class Mnemo < Formula
  desc "Episodic and semantic memory MCP server and CLI"
  homepage "https://github.com/n24q02m/mnemo"
  url "https://files.pythonhosted.org/packages/a2/e5/e4fc26cf3c45fa0932e20cd6211d9c37270514ec2e7c0134591731d8e2ee/n24q02m_mnemo-2.22.0.tar.gz"
  sha256 "215a56331bc20ce41dd7882a09539633754096b61b5bf417dfd4140b2cb35595"
  license "Apache-2.0"

  depends_on "python@3.13"

  def install
    # The sdist pins only this package; its dependencies resolve from PyPI into the
    # private virtualenv, the same set `pip install n24q02m-mnemo` installs.
    system Formula["python@3.13"].opt_bin/"python3.13", "-m", "venv", libexec
    system libexec/"bin/python", "-m", "pip", "install", "--no-cache-dir", buildpath
    # `mnemo` is the memory CLI; `n24q02m-mnemo` starts the MCP server.
    bin.install_symlink libexec/"bin/mnemo", libexec/"bin/n24q02m-mnemo"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/n24q02m-mnemo --version")
  end
end
