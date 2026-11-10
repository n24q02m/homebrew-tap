class Mnemo < Formula
  desc "Episodic and semantic memory MCP server and CLI"
  homepage "https://github.com/n24q02m/mnemo"
  url "https://github.com/n24q02m/mnemo/archive/refs/tags/v2.21.0.tar.gz"
  sha256 "5f9c5b2db82140e40e49500ac4d66d76ab13d4623b2efbbbd812f8e4e8ed028e"
  license "Apache-2.0"

  depends_on "python@3.12"

  def install
    system "python3", "-m", "pip", "install", *std_pip_args, "."
  end

  test do
    system bin/"mnemo", "--help"
  end
end
