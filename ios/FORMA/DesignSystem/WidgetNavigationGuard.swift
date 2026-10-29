import SwiftUI

/// Widget navigation waits for the same Save/Cancel flow that protects a modal's drafts.
///
/// While a link is queued, a banner slides in above the editor under
/// `FormaMotion.reveal` (a fade at Minimal, instant when Off), VoiceOver is told
/// once that the link is waiting, and the banner can be dismissed, which drops
/// the queued link.
private struct WidgetNavigationGuard: ViewModifier {
  @Environment(AppModel.self) private var model
  @Environment(\.formaMotion) private var motion
  let active: Bool
  @State private var registered = false

  private static let message = "Widget link queued. Finish editing to open it."

  private var queued: Bool { active && model.widgetRoute != nil }

  func body(content: Content) -> some View {
    content
      .onOpenURL { model.receiveWidgetURL($0) }
      .safeAreaInset(edge: .top, spacing: 0) {
        if queued {
          banner
            .transition(motion.transition(.opacity.combined(with: .move(edge: .top))))
        }
      }
      .formaAnimation(FormaMotion.reveal, value: queued)
      .onChange(of: queued) { _, isQueued in
        if isQueued { AccessibilityNotification.Announcement(Self.message).post() }
      }
      .onAppear { register(active) }
      .onChange(of: active) { _, value in register(value) }
      .onDisappear { register(false) }
  }

  private var banner: some View {
    HStack(spacing: FormaSpacing.xs) {
      Text(Self.message)
        .font(.footnote).foregroundStyle(FormaTheme.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        model.widgetRoute = nil
      } label: {
        Image(systemName: "xmark")
          .font(.footnote.weight(.semibold))
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .foregroundStyle(FormaTheme.secondary)
      .accessibilityLabel("Dismiss widget link")
      .accessibilityHint("Stays on this screen and does not open the link")
      .accessibilityIdentifier("widget-link-dismiss")
    }
    .padding(.leading, FormaSpacing.sm)
    .frame(maxWidth: .infinity)
    .background(FormaTheme.surface)
    .overlay(alignment: .bottom) { Rectangle().fill(FormaTheme.line).frame(height: 1) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("widget-link-queued")
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
