cask "markedit-in-context" do
  version "0.1.0"
  sha256 "3e310ced65613776278b4f0537f0b0a2319153cca4d03e4ae7e300d3a2ecbc1b"

  url "https://github.com/wundram/MarkEdit-InContext/releases/download/v#{version}/MarkEdit-InContext-#{version}.zip"
  name "MarkEdit InContext"
  desc "In-context Markdown editor for macOS, launched from the terminal"
  homepage "https://github.com/wundram/MarkEdit-InContext"

  depends_on macos: ">= :sequoia"

  app "MarkEdit InContext.app"
  binary "#{appdir}/MarkEdit InContext.app/Contents/Resources/eic", target: "eic"

  zap trash: "~/Library/Preferences/dev.wundram.eic.plist"
end
