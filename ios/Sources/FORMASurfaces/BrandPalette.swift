import Foundation

/// Brand colour values for surfaces that cannot import the app's `FormaTheme` (the widget
/// extension). Plain hex, no UIKit or SwiftUI, so the extension, the app and tests share one table.
/// Each pair mirrors the matching `FormaTheme` token; change both together.
public struct BrandPalette: Equatable, Sendable {
  public struct Token: Equatable, Sendable {
    public let light: UInt32
    public let dark: UInt32
    public let highContrastLight: UInt32
    public let highContrastDark: UInt32

    public func hex(dark isDark: Bool, highContrast: Bool) -> UInt32 {
      switch (isDark, highContrast) {
      case (false, false): light
      case (true, false): dark
      case (false, true): highContrastLight
      case (true, true): highContrastDark
      }
    }
  }

  /// Lime on dark, deep olive on light. Mirrors `FormaTheme.accent`.
  public static let accent = Token(
    light: 0x4C631C, dark: 0xDFF780, highContrastLight: 0x354A0D, highContrastDark: 0xDFF780)
  /// Supporting text. Mirrors `FormaTheme.secondary`.
  public static let secondaryText = Token(
    light: 0x59635D, dark: 0xB9C2BC, highContrastLight: 0x333D35, highContrastDark: 0xE8EDE9)
}
