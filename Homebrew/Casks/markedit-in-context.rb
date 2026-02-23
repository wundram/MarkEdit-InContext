cask "markedit-in-context" do
  version "0.1.0"
  sha256 "7ccbd2e97c8592e15519126aaa0bea43cb41c4139025654d618eeb368c8e5f55"

  url "https://github.com/wundram/MarkEdit-InContext/releases/download/v#{version}/MarkEdit-InContext-#{version}.zip"
  name "MarkEdit InContext"
  desc "In-context Markdown editor for macOS, launched from the terminal"
  homepage "https://github.com/wundram/MarkEdit-InContext"

  depends_on macos: ">= :sequoia"

  app "MarkEdit InContext.app"
  binary "#{appdir}/MarkEdit InContext.app/Contents/Resources/eic", target: "eic"

  zap trash: "~/Library/Preferences/dev.wundram.eic.plist"
end
