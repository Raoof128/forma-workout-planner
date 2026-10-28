import FORMACore
import FORMASurfaces
import Foundation

enum WidgetDestination: Equatable {
  case today, plan, progress, settings, active
  case routine(String)
  case unavailable
}

extension AppModel {
  func receiveWidgetURL(_ url: URL) {
    if let route = WidgetRoute(url: url) { widgetRoute = route }
  }

  func widgetDestination(for route: WidgetRoute) -> WidgetDestination {
    switch route {
    case .today: return .today
    case .plan: return .plan
    case .progress: return .progress
    case .settings: return .settings
    case .routine(let id, let epoch):
      guard widgets.sharing, epoch == widgets.epoch,
        workspace?.routines.contains(where: { $0.id == id && $0.archivedAt == nil }) == true
      else { return .unavailable }
      return .routine(id)
    case .active(let id, let epoch):
      guard widgets.sharing, epoch == widgets.epoch, workspace?.active?.id == id
      else { return .unavailable }
      return .active
    }
  }
}
