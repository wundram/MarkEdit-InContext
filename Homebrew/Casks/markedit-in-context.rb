cask "markedit-in-context" do
  version "0.3.0"
  sha256 "44f85782ceff003faf2836aac5654e02f6d91bcc3d8440a3df20e0486209d949"

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
