class Notion < Formula
  desc "Notion workspace and document MCP server and CLI"
  homepage "https://github.com/n24q02m/notion"
  url "https://github.com/n24q02m/notion/archive/refs/tags/v2.42.0.tar.gz"
  sha256 "36ee40aa7c577e4970ed571cc427aa12b61cb86f5280bb4dde8ca90cc4f8c79f"
  license "Apache-2.0"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    system "#{bin}/notion", "--help"
  end
end
