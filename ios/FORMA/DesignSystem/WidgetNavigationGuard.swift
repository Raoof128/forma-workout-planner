import SwiftUI

/// Widget navigation waits for the same Save/Cancel flow that protects a modal's drafts.
private struct WidgetNavigationGuard: ViewModifier {
  @Environment(AppModel.self) private var model
  let active: Bool
  @State private var registered = false

  func body(content: Content) -> some View {
    content
      .onOpenURL { model.receiveWidgetURL($0) }
      .safeAreaInset(edge: .top, spacing: 0) {
        if active, model.widgetRoute != nil {
          Text("Widget link queued. Finish editing to open it.")
            .font(.footnote).padding(12).frame(maxWidth: .infinity)
            .background(FormaTheme.surface)
            .accessibilityIdentifier("widget-link-queued")
        }
      }
      .onAppear { register(active) }
      .onChange(of: active) { _, value in register(value) }
      .onDisappear { register(false) }
  }

  private func register(_ value: Bool) {
    guard registered != value else { return }
    registered = value
    model.widgetEditingCount = max(0, model.widgetEditingCount + (value ? 1 : -1))
  }
}

extension View {
  func protectWidgetNavigation(while active: Bool = true) -> some View {
    modifier(WidgetNavigationGuard(active: active))
  }
}
