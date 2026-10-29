import Foundation

/// The canonical training calendar shared by app projections and widgets; independent of UI actors.
public enum TrainingCalendar {
  public static let calendar: Calendar = {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
    return calendar
  }()

  /// True when both dates fall in the same training week (Monday first).
  public static func isSameWeek(_ first: Date, _ second: Date) -> Bool {
    guard let interval = calendar.dateInterval(of: .weekOfYear, for: first) else { return false }
    return interval.contains(second)
  }

  public static func completionDate(_ text: String?, startedAt: Double) -> Date {
    if let text {
      if let exact = parseUTC(text) { return exact }
      if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) {
        return date
      }
      if let date = try? Date.ISO8601FormatStyle().parse(text) { return date }
    }
    return Date(timeIntervalSince1970: startedAt / 1000)
  }

  public static func parseUTC(_ text: String) -> Date? {
    var text = text
    return text.withUTF8 { bytes -> Date? in
      let count = bytes.count
      guard count == 20 || count == 24, bytes[count - 1] == 0x5A,
        bytes[4] == 0x2D, bytes[7] == 0x2D, bytes[10] == 0x54, bytes[13] == 0x3A,
        bytes[16] == 0x3A, count == 20 || bytes[19] == 0x2E
      else { return nil }
      func digits(_ start: Int, _ length: Int) -> Int? {
        var value = 0
        for index in start..<start + length {
          let byte = bytes[index]
          guard byte >= 0x30, byte <= 0x39 else { return nil }
          value = value * 10 + Int(byte - 0x30)
        }
        return value
      }
      guard let year = digits(0, 4), let month = digits(5, 2), let day = digits(8, 2),
        let hour = digits(11, 2), let minute = digits(14, 2), let second = digits(17, 2),
        let millis = count == 24 ? digits(20, 3) : 0,
        (1900...2999).contains(year), (1...12).contains(month), hour < 24, minute < 60,
        second < 60
      else { return nil }
      let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
      let monthLength =
        month == 2
        ? (leap ? 29 : 28) : (month == 4 || month == 6 || month == 9 || month == 11) ? 30 : 31
      guard day >= 1, day <= monthLength else { return nil }
      // Days since 1970-01-01 (proleptic Gregorian, Hinnant's civil algorithm).
      let shiftedYear = month <= 2 ? year - 1 : year
      let era = shiftedYear / 400
      let yearOfEra = shiftedYear - era * 400
      let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
      let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
      let days = era * 146_097 + dayOfEra - 719_468
      let seconds = days * 86_400 + hour * 3_600 + minute * 60 + second
      return Date(timeIntervalSince1970: Double(seconds) + Double(millis) / 1_000)
    }
  }
}
