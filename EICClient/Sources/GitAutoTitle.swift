import Foundation

enum GitAutoTitle {
  static func detect(filePath: String) -> String? {
    if filePath.hasSuffix("/.git/COMMIT_EDITMSG") {
      return "Git Commit"
    }
    if filePath.contains("/.git/rebase-merge/") {
      return "Git Rebase"
    }
    if filePath.hasSuffix("/.git/MERGE_MSG") {
      return "Git Merge"
    }
    if filePath.hasSuffix("/.git/TAG_EDITMSG") {
      return "Git Tag"
    }
    if filePath.hasSuffix("/.git/SQUASH_MSG") {
      return "Git Squash"
    }
    return nil
  }
}
