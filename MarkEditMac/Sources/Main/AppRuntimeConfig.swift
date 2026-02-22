//
//  AppRuntimeConfig.swift
//  MarkEditMac
//
//  Created by cyan on 8/9/24.
//

import Foundation
import MarkEditCore
import MarkEditKit

/// Preferences for pro users, not directly visible in the Settings panel.
///
/// The underlying file is stored as "settings.json" in AppCustomization.
enum AppRuntimeConfig {
  struct Definition: Codable {
    enum VisualEffectType: String, Codable {
      case glass = "glass"
      case blur = "blur"
    }

    let autoCharacterPairs: Bool?
    let indentBehavior: EditorIndentBehavior?
    let writingToolsBehavior: String?
    let headerFontSizeDiffs: [Double]?
    let visibleWhitespaceCharacter: String?
    let visibleLineBreakCharacter: String?
    let searchNormalizers: [String: String]?
    let nativeSearchQuerySync: Bool?
    let customToolbarItems: [CustomToolbarItem]?
    let useClassicInterface: Bool?
    let visualEffectType: VisualEffectType?
    let defaultSaveDirectory: String?
    let disableCorsRestrictions: Bool?

    enum CodingKeys: String, CodingKey {
      case autoCharacterPairs = "editor.autoCharacterPairs"
      case indentBehavior = "editor.indentBehavior"
      case writingToolsBehavior = "editor.writingToolsBehavior"
      case headerFontSizeDiffs = "editor.headerFontSizeDiffs"
      case visibleWhitespaceCharacter = "editor.visibleWhitespaceCharacter"
      case visibleLineBreakCharacter = "editor.visibleLineBreakCharacter"
      case searchNormalizers = "editor.searchNormalizers"
      case nativeSearchQuerySync = "editor.nativeSearchQuerySync"
      case customToolbarItems = "editor.customToolbarItems"
      case useClassicInterface = "general.useClassicInterface"
      case visualEffectType = "general.visualEffectType"
      case defaultSaveDirectory = "general.defaultSaveDirectory"
      case disableCorsRestrictions = "general.disableCorsRestrictions"
    }
  }

  static let jsonLiteral: String = {
    {
      guard let fileData, (try? JSONSerialization.jsonObject(with: fileData, options: [])) != nil else {
        Logger.assertFail("Invalid json file was found at: \(AppCustomization.settings.fileURL)")
        return nil
      }

      return fileData.toString()
    }() ?? "{}"
  }()

  static var jsonObject: [String: Any] {
    guard let data = fileData, let object = try? JSONSerialization.jsonObject(with: data) else {
      return [:]
    }

    return (object as? [String: Any]) ?? [:]
  }

  static var autoCharacterPairs: Bool {
    // Enable auto character pairs by default
    currentDefinition?.autoCharacterPairs ?? true
  }

  static var indentBehavior: EditorIndentBehavior {
    // No paragraph or line level indentation by default
    currentDefinition?.indentBehavior ?? .never
  }

  static var writingToolsBehavior: NSWritingToolsBehavior? {
    switch currentDefinition?.writingToolsBehavior {
    case "none": return NSWritingToolsBehavior.none
    case "complete": return NSWritingToolsBehavior.complete
    case "limited": return NSWritingToolsBehavior.limited
    default: return nil
    }
  }

  static var headerFontSizeDiffs: [Double]? {
    // Rely on CoreEditor definitions by default
    currentDefinition?.headerFontSizeDiffs
  }

  static var visibleWhitespaceCharacter: String? {
    currentDefinition?.visibleWhitespaceCharacter
  }

  static var visibleLineBreakCharacter: String? {
    currentDefinition?.visibleLineBreakCharacter
  }

  static var searchNormalizers: [String: String]? {
    currentDefinition?.searchNormalizers
  }

  static var nativeSearchQuerySync: Bool {
    currentDefinition?.nativeSearchQuerySync ?? false
  }

  static var customToolbarItems: [CustomToolbarItem] {
    currentDefinition?.customToolbarItems ?? []
  }

  static var useClassicInterface: Bool {
    currentDefinition?.useClassicInterface ?? false
  }

  static var visualEffectType: Definition.VisualEffectType {
    currentDefinition?.visualEffectType ?? .glass
  }

  static var defaultSaveDirectory: String? {
    // Unspecified by default
    currentDefinition?.defaultSaveDirectory
  }

  static var disableCorsRestrictions: Bool {
    // Enforce CORS restrictions by default
    currentDefinition?.disableCorsRestrictions ?? false
  }

  static var defaultContents: String {
    encode(definition: defaultDefinition)?.toString() ?? ""
  }
}

struct CustomToolbarItem: Codable {
  let title: String
  let icon: String
  let actionName: String?
  let menuName: String?

  var identifier: NSToolbarItem.Identifier {
    let components = [
      title,
      icon,
      actionName,
      menuName,
    ].compactMap { $0 }.joined(separator: "-")

    let prefix = "app.markedit.custom"
    return NSToolbarItem.Identifier(rawValue: "\(prefix).\(components.sha256Hash)")
  }
}

// MARK: - Private

private extension AppRuntimeConfig {
  /**
   The raw JSON data of the settings.json file.
   */
  static let fileData = try? Data(contentsOf: AppCustomization.settings.fileURL)

  static let defaultDefinition = Definition(
    autoCharacterPairs: true,
    indentBehavior: .never,
    writingToolsBehavior: nil, // [macOS 15] Complete mode still has lots of bugs
    headerFontSizeDiffs: nil,
    visibleWhitespaceCharacter: nil,
    visibleLineBreakCharacter: nil,
    searchNormalizers: nil,
    nativeSearchQuerySync: false,
    customToolbarItems: [],
    useClassicInterface: nil,
    visualEffectType: nil,
    defaultSaveDirectory: nil,
    disableCorsRestrictions: nil
  )

  static let currentDefinition: Definition? = {
    guard let fileData else {
      Logger.assertFail("Missing settings.json to proceed")
      return nil
    }

    guard let definition = try? JSONDecoder().decode(Definition.self, from: fileData) else {
      Logger.assertFail("Invalid json object was found: \(fileData)")
      return nil
    }

    return definition
  }()

  static func encode(definition: Definition) -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let jsonData = try? encoder.encode(definition)
    Logger.assert(jsonData != nil, "Failed to encode object: \(definition)")

    return jsonData
  }
}
