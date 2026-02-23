cask "markedit-modal" do
  version "0.1.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/nicwundram/MarkEdit-modal/releases/download/v#{version}/MarkEdit-Modal-#{version}.zip"
  name "MarkEdit Modal"
  desc "Modal Markdown editor for macOS, launched from the terminal"
  homepage "https://github.com/nicwundram/MarkEdit-modal"

  depends_on macos: ">= :sequoia"

  app "MarkEdit Modal.app"
  binary "#{appdir}/MarkEdit Modal.app/Contents/Resources/mem", target: "mem"

  zap trash: "~/Library/Preferences/dev.wundram.mem.plist"
end
