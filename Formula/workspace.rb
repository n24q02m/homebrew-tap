class Workspace < Formula
  desc "Google Workspace MCP server and CLI (Docs, Drive, Gmail, Calendar, Sheets)"
  homepage "https://github.com/n24q02m/workspace"
  url "https://registry.npmjs.org/@n24q02m/workspace/-/workspace-0.7.0.tgz"
  sha256 "b298886ef8391788567d4545ce2250a2516c457334f658ecaef1e3a13d51fc00"
  license "Apache-2.0"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec/"bin/workspace"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/workspace --version")
  end
end
