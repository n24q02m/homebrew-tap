class Telegram < Formula
  desc "Telegram client and bot MCP server and CLI"
  homepage "https://github.com/n24q02m/telegram"
  url "https://github.com/n24q02m/telegram/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "d19381492fc04470125ab092b1262b03ea7d808d5f089a686b43e22ff3a4763c"
  license "Apache-2.0"

  depends_on "python@3.12"

  def install
    system "python3", "-m", "pip", "install", *std_pip_args, "."
  end

  test do
    system "#{bin}/telegram", "--help"
  end
end
