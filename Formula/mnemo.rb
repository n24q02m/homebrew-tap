class Mnemo < Formula
  desc "Episodic and semantic memory MCP server and CLI"
  homepage "https://github.com/n24q02m/mnemo-mcp"
  url "https://github.com/n24q02m/mnemo-mcp/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "a71d999144a95175529a4926ec9c3ab66949384a586aec3103efa6de991f8bfc"
  license "Apache-2.0"

  depends_on "python@3.12"

  def install
    system "python3", "-m", "pip", "install", *std_pip_args, "."
  end

  test do
    system bin/"mnemo", "--help"
  end
end
