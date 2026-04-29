cask "markedit-in-context" do
  version "0.4.0"
  sha256 "d2ef5b80fe9979527158805213c6e3c6a944af9852062ed935f8fbbba203be5c"

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
