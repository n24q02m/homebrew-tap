class Telegram < Formula
  desc "Client and bot MCP server and CLI for Telegram"
  homepage "https://github.com/n24q02m/telegram"
  url "https://github.com/n24q02m/telegram/archive/refs/tags/v4.23.0.tar.gz"
  sha256 "9532da1b6117b9039cccbf75561ac9c1f44d18986b45705818b61791e97be78f"
  license "Apache-2.0"

  depends_on "python@3.12"

  def install
    system "python3", "-m", "pip", "install", *std_pip_args, "."
  end

  test do
    system bin/"n24q02m-telegram", "--help"
  end
end
