cask "markedit-in-context" do
  version "0.2.0"
  sha256 "8a6b5425eb84735e0e74379acdf0a054436674083220742d8c295929ada9cf94"

  url "https://github.com/wundram/MarkEdit-InContext/releases/download/v#{version}/MarkEdit-InContext-#{version}.zip"
  name "MarkEdit InContext"
  desc "In-context Markdown editor for macOS, launched from the terminal"
  homepage "https://github.com/wundram/MarkEdit-InContext"

  depends_on macos: ">= :sequoia"

  app "MarkEdit InContext.app"
  binary "#{appdir}/MarkEdit InContext.app/Contents/Resources/eic", target: "eic"

  zap trash: [
    "~/Library/Preferences/dev.wundram.eic.plist",
    "~/.eic",
  ]
end
