class Crg < Formula
  desc "Code review and AST symbol graph MCP server and CLI"
  homepage "https://github.com/n24q02m/crg"
  url "https://github.com/n24q02m/crg/archive/refs/tags/v3.31.0.tar.gz"
  sha256 "fd65d00aa3b5340a81298448bb14105bd1b467776713911f913782b8b0eaa66d"
  license "Apache-2.0"

  depends_on "python@3.12"

  def install
    system "python3", "-m", "pip", "install", *std_pip_args, "."
  end

  test do
    system bin/"crg", "--help"
  end
end
