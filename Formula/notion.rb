class Notion < Formula
  desc "Workspace and document MCP server and CLI for Notion"
  homepage "https://github.com/n24q02m/notion"
  url "https://registry.npmjs.org/@n24q02m/notion/-/notion-2.43.0.tgz"
  sha256 "dbed8dc399c7af59bda609823786b1db00d71112e77a98c69cc813df2e2d9a19"
  license "Apache-2.0"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec/"bin/notion"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/notion --version")
  end
end
