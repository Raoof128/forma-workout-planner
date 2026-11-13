import FORMACore
import SwiftUI

/// Picks the routine "Your next session" offers. Mirrors the web overview
/// (`src/components/Overview.jsx`): the routine the person chose, else the one
/// after the last trained routine, wrapping to the first. With no history, or
/// when the last routine is gone or archived, it is the first routine.
enum NextRoutine {
  static func select(
    from routines: [Routine], preferredID: String?, lastRoutineID: String?
  ) -> Routine? {
    guard let first = routines.first else { return nil }
    if let preferredID, let chosen = routines.first(where: { $0.id == preferredID }) {
      return chosen
    }
    guard let lastRoutineID, let index = routines.firstIndex(where: { $0.id == lastRoutineID })
    else { return first }
    return routines[(index + 1) % routines.count]
  }
}

extension View {
  /// The hero ink equals the dark canvas, so the card has no edge in dark mode.
  /// A hairline in the line token separates it; light mode already contrasts.
  fileprivate func heroEdge(cornerRadius: CGFloat) -> some View {
    modifier(HeroEdge(cornerRadius: cornerRadius))
  }
}

extension View {
  /// The hero's state, routine name and detail, read as one rotor heading:
  /// "Next session, Upper body strength, 6 exercises · about 50 min".
  fileprivate func heroHeading() -> some View {
    accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
  }
}

/// With the navigation bar hidden, content scrolls under the status bar. iOS 26
/// softens that edge the way a bar would; earlier systems are unchanged.
private struct SoftTopScrollEdge: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.scrollEdgeEffectStyle(.soft, for: .top)
    } else {
      content
    }
  }
}

private struct HeroEdge: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content.overlay {
      if colorScheme == .dark {
        RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(FormaTheme.line, lineWidth: 1)
      }
    }
  }
}

/// "1 routine", "3 routines": the noun agrees with the count.
func countPhrase(_ count: Int, _ noun: String) -> String {
  count == 1 ? "1 \(noun)" : "\(count) \(noun)s"
}

/// What the hero shows. Start and Resume share one hero view so the artwork
/// and button persist and only the text cross-fades between them.
private struct HeroContent {
  let name: String
  let detail: String
  let action: String
  let symbol: String
  let inProgress: Bool
  let perform: () -> Void
}

struct TodayView: View {
  @Environment(AppModel.self) private var model
  @Environment(TrainingNavigation.self) private var navigation
  /// The routine chosen with "Choose another"; nil follows the rotation. Like
  /// the web overview, it lasts for this visit and is not saved.
  @State private var preferredRoutineID: String?
  /// True while `requestStart` waits on the Watch check or the first save, so
  /// the Start tap is acknowledged at once.
  @State private var starting = false
  @Environment(\.dynamicTypeSize) private var textSize
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  private var compactHeight: Bool { verticalSizeClass == .compact }

  var body: some View {
    // `model.routines` filters the whole routine list on every read. Read it
    // once per render rather than five times (once per row for its number).
    let routines = model.routines
    let next = NextRoutine.select(
      from: routines, preferredID: preferredRoutineID,
      lastRoutineID: model.history.first?.routineId)
    ScrollView {
      VStack(alignment: .leading, spacing: FormaSpacing.lg) {
        // The brand row is never a heading: the screen's title is "Today", and
        // the rotor's headings are the hero and the sections below.
        if textSize.isAccessibilitySize {
          brand
        } else {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: FormaSpacing.md) {
              brand
              Spacer(minLength: FormaSpacing.xs)
              date.fixedSize()
            }
            VStack(alignment: .leading, spacing: FormaSpacing.sm) {
              brand
              date
            }
          }
          .accessibilityElement(children: .combine)
          .formaReveal(order: 0)

        }

        // Only present when syncing needs attention, so signed-out layout is unchanged.
        if model.syncDisplay?.needsAttention == true { SyncBanner() }

        if !textSize.isAccessibilitySize && !compactHeight {
          // One sentence set on two lines, so it is read as one. It is a
          // slogan, not a heading.
          VStack(alignment: .leading, spacing: FormaSpacing.xxs) {
            Text("Make room for").textCase(.uppercase)
              .font(.caption.weight(.bold)).tracking(2).foregroundStyle(FormaTheme.secondary)
            Text("Your next stronger.")
              .font(FormaDisplayFont.font(size: 44, relativeTo: .largeTitle))
              .tracking(-0.5).fixedSize(horizontal: false, vertical: true)
              .foregroundStyle(FormaTheme.primary)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Make room for your next stronger.")
          .formaReveal(order: 1)

        }

        // A stable container: the reveal plays once for the hero's lifetime,
        // however often Start and Resume swap inside it.
        VStack(alignment: .leading, spacing: 0) {
          if let hero = heroContent(next: next) {
            if compactHeight { compactTrainingHero(hero) } else { trainingHero(hero) }
            if !hero.inProgress, routines.count > 1, let next {
              chooseAnother(routines, next: next)
            }
          } else {
            // An empty screen offers the way forward, not only directions.
            ContentUnavailableView {
              Label("Your training starts here", systemImage: "dumbbell")
            } description: {
              Text("Create a routine in Plan, then make it yours one set at a time.")
            } actions: {
              Button("Open Plan") { navigation.select(.plan) }
                .buttonStyle(.formaPrimaryCompact)
                .accessibilityHint("Create your first routine there.")
                .accessibilityIdentifier("today-open-plan")
            }
          }
        }
        .formaReveal(order: 2)

        WeekStrip()
          .formaReveal(order: 3)

        // No routines means no section: the empty state above already says so.
        if !routines.isEmpty {
          routineList(routines)
            .formaReveal(order: 4)
        }

        VStack(alignment: .leading, spacing: 0) {
          if let recent = model.history.first {
            VStack(alignment: .leading, spacing: FormaSpacing.sm) {
              SectionHeading(
                title: "Last time you showed up",
                detail: TrainingDate.label(TrainingDate.date(recent)))
              NavigationLink(value: TrainingRoute.session(recent.id)) {
                HStack {
                  Image(systemName: "checkmark.seal.fill").foregroundStyle(FormaTheme.accent)
                    .accessibilityHidden(true)
                  Text(recent.name).font(.headline)
                  Spacer()
                  Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .foregroundStyle(FormaTheme.primary).padding(FormaSpacing.lg)
                .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: FormaRadius.card))
                // Surface on canvas is about 1.1:1, so a hairline gives the
                // card the same edge as the Watch strip and the sheets.
                .overlay(
                  RoundedRectangle(cornerRadius: FormaRadius.card).strokeBorder(FormaTheme.line))
              }
              .buttonStyle(PressableCardStyle())
            }
          } else {
            HStack(alignment: .top, spacing: FormaSpacing.sm) {
              Image(systemName: "sparkle").foregroundStyle(FormaTheme.accent)
                .accessibilityHidden(true)
              Text("A fresh page. Your first completed workout will appear here.")
                .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            }
          }
        }
        .formaReveal(order: 5)
        LocalSaveStatus(saving: model.busy)
          .formaReveal(order: 6)
      }
      .padding(FormaSpacing.xl)
      .id(TabScrollAnchor.top)
    }
    .background(FormaTheme.canvas)
    .modifier(SoftTopScrollEdge())
    .formaTabRoot(.today)
    // The bar stays hidden, but the title names the screen for VoiceOver and
    // gives screens pushed from here a "Today" back button.
    .navigationTitle("Today")
    .toolbar(.hidden, for: .navigationBar)
  }

  private func routineList(_ routines: [Routine]) -> some View {
    VStack(alignment: .leading, spacing: FormaSpacing.md) {
      SectionHeading(
        title: "Your training space", detail: countPhrase(routines.count, "routine"))
      ForEach(Array(routines.prefix(3).enumerated()), id: \.element.id) { position, routine in
        NavigationLink(value: TrainingRoute.routine(routine.id)) {
          HStack(spacing: FormaSpacing.md) {
            Text(String(format: "%02d", position + 1))
              .font(.title2.weight(.black).monospacedDigit()).foregroundStyle(FormaTheme.accent)
              .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FormaSpacing.xxs) {
              Text(routine.name).font(.headline).foregroundStyle(FormaTheme.primary)
              Text(
                "\(countPhrase(routine.exercises.count, "exercise")) · \(routine.minutes) min"
              )
              .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(FormaTheme.secondary)
              .accessibilityHidden(true)
          }
          .padding(.vertical, FormaSpacing.sm).contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        Divider().overlay(FormaTheme.line)
      }
      if routines.count > 3 {
        Button {
          navigation.select(.plan)
        } label: {
          HStack {
            Text("See all \(routines.count) routines").font(.headline)
            Spacer(minLength: FormaSpacing.xs)
            Image(systemName: "chevron.right").accessibilityHidden(true)
          }
          .foregroundStyle(FormaTheme.accent)
          .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityHint("Opens Plan.")
        .accessibilityIdentifier("see-all-routines")
      }
    }
  }

  /// The hero's content for the current state, or nil when there is no routine
  /// to start. Reads `activeWorkoutName` (not `workspace`), which changes only
  /// when a workout starts or ends.
  private func heroContent(next: Routine?) -> HeroContent? {
    if let name = model.activeWorkoutName {
      return HeroContent(
        name: name, detail: "Pick up exactly where you left off.",
        action: "Resume workout", symbol: "play.fill", inProgress: true
      ) {
        model.receipt = nil
        model.workoutPresented = true
      }
    }
    guard let routine = next else { return nil }
    return HeroContent(
      name: routine.name,
      detail:
        "\(countPhrase(routine.exercises.count, "exercise")) · about \(routine.minutes) min",
      action: "Start workout", symbol: "play.fill", inProgress: false
    ) {
      starting = true
      Task {
        await model.requestStart(routine)
        starting = false
      }
    }
  }

  /// The rotation can be wrong for today, so the hero offers every routine
  /// without a trip through Plan. The choice lasts for this visit.
  private func chooseAnother(_ routines: [Routine], next: Routine) -> some View {
    Menu {
      Picker(
        "Next session",
        selection: Binding(get: { next.id }, set: { preferredRoutineID = $0 })
      ) {
        ForEach(routines) { Text($0.name).tag($0.id) }
      }
    } label: {
      Label("Choose another session", systemImage: "arrow.left.arrow.right")
        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
    }
    .foregroundStyle(FormaTheme.accent)
    .disabled(model.busy || starting)
    .accessibilityIdentifier("choose-next-session")
  }

  private func compactTrainingHero(_ hero: HeroContent) -> some View {
    let pending = starting && !hero.inProgress
    return HStack(spacing: FormaSpacing.lg) {
      VStack(alignment: .leading, spacing: FormaSpacing.xxs) {
        Text(hero.inProgress ? "In progress" : "Next session").textCase(.uppercase)
          .font(.caption.weight(.bold)).foregroundStyle(FormaTheme.lime)
        Text(hero.name).font(.title3.bold()).foregroundStyle(.white)
          .fixedSize(horizontal: false, vertical: true)
        Text(hero.detail).font(.subheadline).foregroundStyle(FormaTheme.heroDetail)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .heroHeading()
      Button(action: hero.perform) {
        // The same pending treatment as the regular hero.
        Label {
          Text(hero.action)
        } icon: {
          if pending {
            ProgressView().tint(FormaTheme.ink)
          } else {
            Image(systemName: hero.symbol)
          }
        }
      }
      .buttonStyle(.formaPrimaryOnDark)
      .frame(maxWidth: 260)
      .accessibilityLabel(hero.action)
      .accessibilityValue(pending ? "Starting" : "")
      .accessibilityIdentifier("start-workout")
      .disabled(model.busy || pending)
    }
    .padding(FormaSpacing.lg)
    .background(FormaTheme.heroInk, in: RoundedRectangle(cornerRadius: FormaRadius.hero))
    .heroEdge(cornerRadius: FormaRadius.hero)
  }

  private func trainingHero(_ hero: HeroContent) -> some View {
    let pending = starting && !hero.inProgress
    return VStack(alignment: .leading, spacing: 0) {
      if !textSize.isAccessibilitySize {
        // A fixed-height clear frame with the photo as an overlay crops it
        // without a GeometryReader, and the photo never sizes the layout.
        // The website's hero photo: the athlete sits in its right half, so the
        // strip keeps that side in view.
        Group {
          if let hero = ExerciseMediaLibrary.shared.photos?.hero {
            MediaPhoto(photo: hero, focusX: 0.85)
          } else {
            // The earlier editorial artwork, if the media folder is missing.
            Color.clear.overlay(alignment: .bottom) {
              Image("TrainingEditorial").resizable().scaledToFill()
            }
            .clipped()
          }
        }
        // A photograph, so Smart Invert leaves it as taken.
        .accessibilityIgnoresInvertColors()
        .frame(height: 132)
        .overlay(alignment: .bottom) {
          LinearGradient(
            colors: [.clear, FormaTheme.heroInk], startPoint: .top, endPoint: .bottom
          )
          .frame(height: 40)
        }
        .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: FormaSpacing.xs) {
        if textSize.isAccessibilitySize {
          Text(hero.inProgress ? "In progress" : "Next session")
            .font(.caption.weight(.bold)).foregroundStyle(FormaTheme.lime)
        } else {
          Label(
            hero.inProgress ? "In progress" : "Next session",
            systemImage: hero.inProgress ? "play.circle" : "arrow.turn.down.right"
          )
          .textCase(.uppercase)
          .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(FormaTheme.lime)
        }
        Text(hero.name)
          .font(FormaDisplayFont.font(size: 28, relativeTo: .title2))
          .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
        if !textSize.isAccessibilitySize {
          Text(hero.detail).font(.subheadline).foregroundStyle(FormaTheme.heroDetail)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.horizontal, FormaSpacing.lg)
      .padding(.top, textSize.isAccessibilitySize ? FormaSpacing.lg : FormaSpacing.xs)
      .heroHeading()
      .id(hero.inProgress).transition(.opacity)
      Button(action: hero.perform) {
        ZStack {
          HStack {
            Text(hero.action)
            Spacer()
            if pending {
              // Acknowledges the tap while the Watch check or first save runs.
              ProgressView().tint(FormaTheme.ink)
            } else {
              Image(systemName: hero.symbol)
            }
          }
          .id(hero.inProgress)
          .transition(.opacity)
        }
      }
      .buttonStyle(.formaPrimaryOnDark)
      // The label is explicit so the outgoing text, which lingers for the
      // cross-fade, never leaks into it.
      .accessibilityLabel(hero.action)
      .accessibilityValue(pending ? "Starting" : "")
      .accessibilityIdentifier("start-workout")
      .disabled(model.busy || pending)
      // The button's bottom corners sit in the hero's: an 8pt inset makes its
      // 16pt radius concentric with the hero's 24pt. At accessibility sizes the
      // detail follows the button, so it keeps the wider inset.
      .padding(.horizontal, textSize.isAccessibilitySize ? FormaSpacing.md : FormaSpacing.xs)
      .padding(.top, FormaSpacing.md)
      .padding(.bottom, textSize.isAccessibilitySize ? FormaSpacing.md : FormaSpacing.xs)
      .background(FormaTheme.heroInk)
      if textSize.isAccessibilitySize {
        // Keep the primary action above the fold on a compact phone at the
        // largest text size. Metadata stays readable below it, without capping type.
        Text(hero.detail).font(.subheadline).foregroundStyle(FormaTheme.heroDetail)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, FormaSpacing.lg).padding(.bottom, FormaSpacing.lg)
      }
    }
    .background(FormaTheme.heroInk)
    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.hero))
    .heroEdge(cornerRadius: FormaRadius.hero)
    .formaAnimation(FormaMotion.reveal, value: model.activeWorkoutName)
  }

  private var brand: some View {
    HStack(spacing: FormaSpacing.xs) {
      FormaMark().fill(FormaTheme.ink).frame(width: 32, height: 32)
        .padding(FormaSpacing.xxs)
        .background(FormaTheme.lime, in: RoundedRectangle(cornerRadius: FormaRadius.field))
      Text("FORMA").font(.title3.weight(.black)).tracking(3).foregroundStyle(FormaTheme.primary)
    }.fixedSize()
  }
  private var date: some View {
    Text(TrainingDate.label(model.trainingNow, template: "EEE d MMM"))
      .font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.secondary)
  }
}

struct WeekStrip: View {
  @Environment(AppModel.self) private var model
  @Environment(\.formaMotion) private var motion
  @Environment(\.dynamicTypeSize) private var textSize
  /// The completed weekdays the circles currently draw. nil until the strip
  /// first appears, so days already complete are simply shown complete. It
  /// follows the committed history only while the workout screen is closed,
  /// which is when a newly completed day can actually be seen filling in.
  @State private var drawn: Set<Int>?
  /// The circles grow with the day letters and checkmarks they hold. The
  /// accessibility sizes use the list of rows instead.
  @ScaledMetric(relativeTo: .caption) private var dot: CGFloat = 34
  @ScaledMetric(relativeTo: .caption) private var plannedMark: CGFloat = 5
  /// Built once, not on every render of the strip.
  private static let shortDays = weekdaySymbols(short: true)
  private static let longDays = weekdaySymbols(short: false)
  private var days: [String] { Self.shortDays }
  private var fullDays: [String] { Self.longDays }

  /// Weekday names from Monday (the training week's first day in Sydney) in
  /// the app's own language, so they translate with the rest of the copy.
  static func weekdaySymbols(
    short: Bool,
    locale: Locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
  ) -> [String] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = locale
    let sundayFirst =
      short ? calendar.veryShortStandaloneWeekdaySymbols : calendar.standaloneWeekdaySymbols
    return Array(sundayFirst.dropFirst()) + [sundayFirst[0]]
  }

  /// "2 of 4 workouts", spoken as words rather than "2 slash 4".
  static func progressDetail(count: Int, goal: Int) -> String {
    "\(count) of \(countPhrase(goal, "workout"))"
  }

  /// Sessions and weekdays (Monday = 0) completed this week. `model.history`
  /// is sorted newest first, so stop at the first session before this week
  /// instead of parsing every saved date (up to 10,000) on each render.
  private func thisWeek() -> (count: Int, days: Set<Int>) {
    guard let interval = TrainingDate.calendar.dateInterval(of: .weekOfYear, for: model.trainingNow)
    else {
      return (0, [])
    }
    var count = 0
    var days = Set<Int>()
    for session in model.history {
      let date = TrainingDate.date(session)
      if date < interval.start { break }
      guard date < interval.end, date <= model.trainingNow else { continue }
      count += 1
      days.insert((TrainingDate.calendar.component(.weekday, from: date) + 5) % 7)
    }
    return (count, days)
  }

  /// Monday = 0, like the sets above.
  private var todayIndex: Int {
    (TrainingDate.calendar.component(.weekday, from: model.trainingNow) + 5) % 7
  }

  /// One sentence of state for a day, in the order VoiceOver reads it. Built
  /// from committed history, never from what the circles have animated to.
  private func status(day: Int, trained: Bool, scheduled: Bool, today: Int) -> String {
    if trained { return "Completed" }
    if day == today {
      return scheduled ? "Not yet trained, planned training day" : "Not yet trained"
    }
    if day > today { return scheduled ? "Planned training day" : "No workout planned" }
    return scheduled ? "Planned training day, not completed" : "No workout recorded"
  }

  /// Brings the drawn days up to the committed ones, with the one-time
  /// emphasis. Deferred while the workout cover is up: the strip is behind it.
  private func syncDrawn(to completed: Set<Int>) {
    guard drawn != completed, !model.workoutPresented else { return }
    withFormaAnimation(motion, FormaMotion.emphasis) { drawn = completed }
  }

  var body: some View {
    let week = thisWeek()
    let completedDays = week.days
    let shownDays = drawn ?? completedDays
    let today = todayIndex
    let schedule = model.workspace?.schedule ?? []
    VStack(alignment: .leading, spacing: FormaSpacing.md) {
      // A heading that names the section, so the rotor lands somewhere useful.
      SectionHeading(
        title: "This week",
        detail: Self.progressDetail(count: week.count, goal: model.workspace?.profile.goal ?? 4))
      if textSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: FormaSpacing.md) {
          ForEach(0..<7) { day in
            VStack(alignment: .leading, spacing: FormaSpacing.xxs) {
              Text(day == today ? "\(fullDays[day]) · Today" : fullDays[day]).font(.headline)
              Text(
                status(
                  day: day, trained: completedDays.contains(day),
                  scheduled: schedule.contains(day), today: today)
              )
              .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            }.accessibilityElement(children: .combine)
          }
        }
      } else {
        HStack(spacing: 0) {
          ForEach(0..<7) { day in
            let trained = shownDays.contains(day)
            let scheduled = schedule.contains(day)
            let isToday = day == today
            // Spoken from committed history, so it is already right while the
            // circle is still animating.
            let spoken = status(
              day: day, trained: completedDays.contains(day), scheduled: scheduled, today: today)
            VStack(spacing: FormaSpacing.xs) {
              Text(days[day]).font(.caption.weight(isToday ? .heavy : .semibold))
                .foregroundStyle(isToday ? FormaTheme.primary : FormaTheme.secondary)
                // Today is marked by shape too, not only by weight and colour.
                .overlay(alignment: .bottom) {
                  if isToday {
                    Capsule().fill(FormaTheme.accent).frame(width: 12, height: 2)
                      .offset(y: FormaSpacing.xxs)
                  }
                }
              ZStack {
                Circle().fill(trained ? FormaTheme.lime : FormaTheme.surface)
                Circle().strokeBorder(
                  scheduled ? FormaTheme.accent : FormaTheme.boundary,
                  style: StrokeStyle(
                    lineWidth: scheduled ? 1.5 : 1, dash: scheduled && !trained ? [3, 3] : []))
                if trained {
                  Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(
                    FormaTheme.ink
                  )
                  .transition(motion.transition(.scale(scale: 0.3).combined(with: .opacity)))
                } else if scheduled {
                  Circle().fill(FormaTheme.accent).frame(width: plannedMark, height: plannedMark)
                    .transition(.opacity)
                }
              }.frame(width: dot, height: dot)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(isToday ? "Today" : fullDays[day]), \(spoken.lowercased())")
          }
        }
      }
      if !textSize.isAccessibilitySize {
        Text("Dashed circles are planned days. Checks are completed workouts.")
          .font(.caption).foregroundStyle(FormaTheme.secondary)
      }
    }
    .onAppear {
      if drawn == nil { drawn = completedDays } else { syncDrawn(to: completedDays) }
    }
    .onChange(of: completedDays) { syncDrawn(to: completedDays) }
    .onChange(of: model.workoutPresented) { syncDrawn(to: completedDays) }
  }
}
