import Foundation

public enum WidgetRoute: Equatable, Sendable, Hashable {
  case today, plan, progress, settings
  case routine(id: String, epoch: String)
  case active(id: String, epoch: String)

  public var url: URL {
    var components = URLComponents()
    components.scheme = "forma"
    components.host = "widget"
    switch self {
    case .today: components.path = "/today"
    case .plan: components.path = "/plan"
    case .progress: components.path = "/progress"
    case .settings: components.path = "/settings"
    case .routine(let id, let epoch):
      components.path = "/routine"
      components.queryItems = [
        URLQueryItem(name: "id", value: id), URLQueryItem(name: "epoch", value: epoch),
      ]
    case .active(let id, let epoch):
      components.path = "/active"
      components.queryItems = [
        URLQueryItem(name: "id", value: id), URLQueryItem(name: "epoch", value: epoch),
      ]
    }
    // All structural fields above are app constants; query values are percent encoded.
    return components.url!
  }

  public init?(url: URL) {
    guard url.absoluteString.utf8.count <= 4096,
      let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      parts.scheme == "forma", parts.host == "widget", parts.user == nil,
      parts.password == nil, parts.port == nil, parts.fragment == nil
    else { return nil }
    let items = parts.queryItems ?? []
    switch parts.path {
    case "/today" where items.isEmpty: self = .today
    case "/plan" where items.isEmpty: self = .plan
    case "/progress" where items.isEmpty: self = .progress
    case "/settings" where items.isEmpty: self = .settings
    case "/routine", "/active":
      guard items.count == 2, Set(items.map(\.name)) == ["id", "epoch"],
        let id = items.first(where: { $0.name == "id" })?.value,
        let epoch = items.first(where: { $0.name == "epoch" })?.value,
        !id.isEmpty, id.utf16.count <= 200, !epoch.isEmpty, epoch.utf16.count <= 200
      else { return nil }
      self =
        parts.path == "/routine" ? .routine(id: id, epoch: epoch) : .active(id: id, epoch: epoch)
    default: return nil
    }
  }
}
