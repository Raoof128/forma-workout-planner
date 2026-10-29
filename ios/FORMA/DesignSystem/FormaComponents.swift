import SwiftUI

/// The FORMA mark assembling while genuine work is pending (opening the local
/// training store). It plays once and then holds still; it never loops and is
/// never shown to make the user wait. Minimal fades it in; off shows it whole.
struct FormaLoadingMark: View {
  @Environment(\.formaMotion) private var level
  @State private var assembled = false

  var body: some View {
    ZStack {
      ForEach(0..<FormaMark.facetCount, id: \.self) { facet in
        FormaMark(facet: facet).fill(FormaTheme.accent)
          .opacity(assembled || level == .off ? 1 : 0)
          .offset(y: assembled || !level.allowsSpatialMotion ? 0 : 6)
          .scaleEffect(assembled || !level.allowsSpatialMotion ? 1 : 0.9, anchor: .bottom)
          .animation(
            level.animation(FormaMotion.reveal)?.delay(Double(facet) * 0.08), value: assembled)
      }
    }
    .accessibilityHidden(true)
    .onAppear { assembled = true }
  }
}

/// The receipt's seal: the FORMA mark on lime, ringed once as the finished
/// workout is shown. The receipt only exists after the workout has been saved,
/// so the emphasis and the single success haptic confirm a real, durable
/// result. Minimal fades it in; off shows it complete and still.
struct CompletionSeal: View {
  @Environment(\.formaMotion) private var level
  @Environment(AppModel.self) private var model
  @ScaledMetric(relativeTo: .largeTitle) private var size = 72.0
  @State private var sealed = false

  var body: some View {
    let settled = sealed || level == .off
    ZStack {
      Circle().fill(FormaTheme.lime)
      Circle()
        .trim(from: 0, to: settled ? 1 : 0)
        .stroke(FormaTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .padding(-6)
      FormaMark().fill(FormaTheme.ink).padding(size * 0.2)
    }
    .frame(width: size, height: size)
    .scaleEffect(settled || !level.allowsSpatialMotion ? 1 : 0.7)
    .opacity(settled ? 1 : 0)
    .animation(level.animation(FormaMotion.emphasis), value: sealed)
    .sensoryFeedback(.success, trigger: sealed) { _, new in new && model.hapticsEnabled }
    .accessibilityHidden(true)
    .onAppear { sealed = true }
  }
}
