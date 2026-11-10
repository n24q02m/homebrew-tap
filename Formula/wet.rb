class Wet < Formula
  desc "Streamable HTTP/stdio MCP server and CLI for web extraction and search"
  homepage "https://github.com/n24q02m/wet"
  url "https://github.com/n24q02m/wet/archive/refs/tags/v3.20.0.tar.gz"
  sha256 "adebec9bc07492732aa2d4756d9c7cad631ce4f8a837dd9ad3b6f577e0a70655"
  license "Apache-2.0"

  depends_on "python@3.12"

  def install
    system "python3", "-m", "pip", "install", *std_pip_args, "."
  end

  test do
    system bin/"wet", "--help"
  end
end
