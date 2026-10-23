import Foundation
import XCTest

@testable import FORMACore

final class MeasurementNumberInputTests: XCTestCase {
  func testWholeInputAcceptsLocaleDigitsAndItsDecimalSeparator() {
    XCTAssertEqual(MeasurementNumberInput.parse("٢٫٥", locale: Locale(identifier: "ar_EG")), 2.5)
    XCTAssertEqual(MeasurementNumberInput.parse("۲٫۵", locale: Locale(identifier: "fa_IR")), 2.5)
    XCTAssertEqual(MeasurementNumberInput.parse(" २.५ ", locale: Locale(identifier: "hi_IN")), 2.5)
    for locale in ["en_AU", "fr_FR", "de_DE"] {
      XCTAssertEqual(MeasurementNumberInput.parse("2.5", locale: Locale(identifier: locale)), 2.5)
      XCTAssertEqual(MeasurementNumberInput.parse("2,5", locale: Locale(identifier: locale)), 2.5)
    }
  }

  func testInvalidSuffixPrefixGroupingAndNonFiniteInputAreRejectedInFull() {
    for input in [
      "", " ", "12kg", "kg12", "1,234.5", "1.234,5", "2 500", "2\u{202F}500", "NaN", "inf", "1e309",
      "++2", "--2", "2-1", "٢٬٥٠٠", "٢٫٥kg",
    ] {
      XCTAssertNil(MeasurementNumberInput.parse(input, locale: Locale(identifier: "ar_EG")), input)
    }
    XCTAssertNil(MeasurementNumberInput.parse("٢٫٥", locale: Locale(identifier: "en_AU")))
  }

  func testFiniteSignsAndScientificNotationRetainTheirMeaning() {
    let locale = Locale(identifier: "en_AU")
    XCTAssertEqual(MeasurementNumberInput.parse("+2.5", locale: locale), 2.5)
    XCTAssertEqual(MeasurementNumberInput.parse("-2.5", locale: locale), -2.5)
    XCTAssertEqual(MeasurementNumberInput.parse("1.25e-7", locale: locale), 1.25e-7)
    XCTAssertEqual(
      MeasurementNumberInput.parse("١٫٢٥e-٧", locale: Locale(identifier: "ar_EG")), 1.25e-7)
  }

  func testDisplayRoundTripsEveryStoredDigitAcrossLocalesWithoutRounding() {
    let values = [0.0, 0.1, 50.12345678912345, 0.00000000000000000001, 1e20, 1000.00000000001]
    for name in ["en_AU", "fr_FR", "de_DE", "ar_EG", "fa_IR"] {
      let locale = Locale(identifier: name)
      for value in values {
        let text = MeasurementNumberInput.display(value, locale: locale)
        XCTAssertEqual(
          MeasurementNumberInput.parse(text, locale: locale), value, "\(name): \(text)")
      }
    }
  }

  func testDisplayUsesDecimalSeparatorWithoutAddingGrouping() {
    XCTAssertEqual(
      MeasurementNumberInput.display(1234.5, locale: Locale(identifier: "en_AU")), "1234.5")
    XCTAssertEqual(
      MeasurementNumberInput.display(1234.5, locale: Locale(identifier: "fr_FR")), "1234,5")
    XCTAssertEqual(
      MeasurementNumberInput.display(1234.5, locale: Locale(identifier: "ar_EG")), "1234٫5")
    XCTAssertEqual(MeasurementNumberInput.display(12, locale: Locale(identifier: "fr_FR")), "12")
  }
}
