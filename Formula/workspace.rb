class Workspace < Formula
  desc "Google Workspace MCP server and CLI (Docs, Drive, Gmail, Calendar, Sheets)"
  homepage "https://github.com/n24q02m/workspace"
  url "https://github.com/n24q02m/workspace/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "a09b9ea9ad4b51b65c92d2db2b3978b85661507c8b5f498ab34ce7aa548e3415"
  license "Apache-2.0"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    system "#{bin}/workspace", "--help"
  end
end
