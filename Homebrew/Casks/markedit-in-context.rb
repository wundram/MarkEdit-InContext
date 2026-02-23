cask "markedit-in-context" do
  version "0.1.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/nicwundram/MarkEdit-modal/releases/download/v#{version}/MarkEdit-InContext-#{version}.zip"
  name "MarkEdit InContext"
  desc "In-context Markdown editor for macOS, launched from the terminal"
  homepage "https://github.com/nicwundram/MarkEdit-modal"

  depends_on macos: ">= :sequoia"

  app "MarkEdit InContext.app"
  binary "#{appdir}/MarkEdit InContext.app/Contents/Resources/eic", target: "eic"

  zap trash: "~/Library/Preferences/dev.wundram.eic.plist"
end
