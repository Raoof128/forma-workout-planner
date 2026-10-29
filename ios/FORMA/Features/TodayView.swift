import FORMACore
import SwiftUI

/// Hero colours are fixed, so build each `UIColor` once instead of per render.
private enum HeroColor {
  static let ink = Color(hex: 0x151A17)
  static let detail = Color(hex: 0xDEE5DC)
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
  /// True while `requestStart` waits on the Watch check or the first save, so
  /// the Start tap is acknowledged at once.
  @State private var starting = false
  @Environment(\.dynamicTypeSize) private var textSize
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  private var compactHeight: Bool { verticalSizeClass == .compact }
  @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 40.0

  var body: some View {
    // `model.routines` filters the whole routine list on every read. Read it
    // once per render rather than five times (once per row for its number).
    let routines = model.routines
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        if textSize.isAccessibilitySize {
          brand.accessibilityAddTraits(.isHeader)
        } else {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
              brand
              Spacer(minLength: 8)
              date.fixedSize()
            }
            VStack(alignment: .leading, spacing: 12) {
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
          VStack(alignment: .leading, spacing: 6) {
            Text("MAKE ROOM FOR").font(.caption.weight(.bold)).tracking(2).foregroundStyle(
              FormaTheme.secondary)
            Text("Your next stronger.")
              .font(.system(size: titleSize, weight: .black).width(.condensed))
              .tracking(-0.6).fixedSize(horizontal: false, vertical: true)
              .foregroundStyle(FormaTheme.primary).accessibilityAddTraits(.isHeader)
          }
          .formaReveal(order: 1)

        }

        // A stable container: the reveal plays once for the hero's lifetime,
        // however often Start and Resume swap inside it.
        VStack(alignment: .leading, spacing: 0) {
          if let hero = heroContent(routines: routines) {
            if compactHeight { compactTrainingHero(hero) } else { trainingHero(hero) }
          } else {
            ContentUnavailableView {
              Label("Your training starts here", systemImage: "dumbbell")
            } description: {
              Text("Create a routine in Plan, then make it yours one set at a time.")
            }
          }
        }
        .formaReveal(order: 2)

        WeekStrip()
          .formaReveal(order: 3)

        VStack(alignment: .leading, spacing: 16) {
          SectionHeading(title: "Your training space", detail: "\(routines.count) routines")
          ForEach(Array(routines.prefix(3).enumerated()), id: \.element.id) { position, routine in
            NavigationLink {
              RoutineDetailView(routine: routine)
            } label: {
              HStack(spacing: 16) {
                Text(String(format: "%02d", position + 1))
                  .font(.title2.weight(.black).monospacedDigit()).foregroundStyle(FormaTheme.accent)
                VStack(alignment: .leading, spacing: 5) {
                  Text(routine.name).font(.headline).foregroundStyle(FormaTheme.primary)
                  Text("\(routine.exercises.count) exercises · \(routine.minutes) min")
                    .font(.subheadline).foregroundStyle(FormaTheme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").foregroundStyle(FormaTheme.secondary)
              }
              .padding(.vertical, 12).contentShape(Rectangle())
            }
            .buttonStyle(PressableCardStyle())
            Divider().overlay(FormaTheme.line)
          }
        }
        .formaReveal(order: 4)

        VStack(alignment: .leading, spacing: 0) {
          if let recent = model.history.first {
            VStack(alignment: .leading, spacing: 12) {
              SectionHeading(
                title: "Last time you showed up",
                detail: TrainingDate.label(TrainingDate.date(recent)))
              NavigationLink {
                SessionDetailView(session: recent)
              } label: {
                HStack {
                  Image(systemName: "checkmark.seal.fill").foregroundStyle(FormaTheme.accent)
                  Text(recent.name).font(.headline)
                  Spacer()
                  Image(systemName: "chevron.right")
                }
                .foregroundStyle(FormaTheme.primary).padding(20)
                .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 18))
              }
              .buttonStyle(PressableCardStyle())
            }
          } else {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "sparkle").foregroundStyle(FormaTheme.accent)
              Text("A fresh page. Your first completed workout will appear here.")
                .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            }
          }
        }
        .formaReveal(order: 5)
        LocalSaveStatus(saving: model.busy)
          .formaReveal(order: 6)
      }
      .padding(24)
    }
    .background(FormaTheme.canvas)
    .formaTabScrollObserver()
    .toolbar(.hidden, for: .navigationBar)
  }

  /// The hero's content for the current state, or nil when there is no routine
  /// to start. Reads `activeWorkoutName` (not `workspace`), which changes only
  /// when a workout starts or ends.
  private func heroContent(routines: [Routine]) -> HeroContent? {
    if let name = model.activeWorkoutName {
      return HeroContent(
        name: name, detail: "Pick up exactly where you left off.",
        action: "Resume workout", symbol: "play.fill", inProgress: true
      ) {
        model.receipt = nil
        model.workoutPresented = true
      }
    }
    guard let routine = routines.first else { return nil }
    return HeroContent(
      name: routine.name,
      detail: "\(routine.exercises.count) exercises · about \(routine.minutes) min",
      action: "Start workout", symbol: "arrow.up.right", inProgress: false
    ) {
      starting = true
      Task {
        await model.requestStart(routine)
        starting = false
      }
    }
  }

  private func compactTrainingHero(_ hero: HeroContent) -> some View {
    HStack(spacing: 20) {
      VStack(alignment: .leading, spacing: 5) {
        Text(hero.inProgress ? "IN PROGRESS" : "YOUR NEXT SESSION")
          .font(.caption.weight(.bold)).foregroundStyle(FormaTheme.lime)
        Text(hero.name).font(.title3.bold()).foregroundStyle(.white)
          .fixedSize(horizontal: false, vertical: true)
        Text(hero.detail).font(.subheadline).foregroundStyle(HeroColor.detail)
      }.frame(maxWidth: .infinity, alignment: .leading)
      Button(action: hero.perform) {
        Label(hero.action, systemImage: starting ? "hourglass" : hero.symbol)
      }
      .buttonStyle(PrimaryButtonStyle())
      .frame(maxWidth: 260)
      .accessibilityLabel(hero.action)
      .accessibilityValue(starting ? "Starting" : "")
      .accessibilityIdentifier("start-workout")
      .disabled(model.busy || starting)
    }
    .padding(20)
    .background(HeroColor.ink, in: RoundedRectangle(cornerRadius: 24))
  }

  private func trainingHero(_ hero: HeroContent) -> some View {
    let pending = starting && !hero.inProgress
    return VStack(alignment: .leading, spacing: 0) {
      if !textSize.isAccessibilitySize {
        GeometryReader { geometry in
          Image("TrainingEditorial").resizable().scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .clipped()
        }
        .frame(height: 112)
        .overlay(alignment: .bottom) {
          LinearGradient(colors: [.clear, HeroColor.ink], startPoint: .top, endPoint: .bottom)
            .frame(height: 40)
        }
        .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 8) {
        if textSize.isAccessibilitySize {
          Text(hero.inProgress ? "In progress" : "Next session")
            .font(.caption.weight(.bold)).foregroundStyle(FormaTheme.lime)
        } else {
          Label(
            hero.inProgress ? "IN PROGRESS" : "YOUR NEXT SESSION",
            systemImage: hero.inProgress ? "play.circle" : "arrow.turn.down.right"
          )
          .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(FormaTheme.lime)
        }
        Text(hero.name)
          .font(.system(.title2, weight: .bold).width(.condensed))
          .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
        if !textSize.isAccessibilitySize {
          Text(hero.detail).font(.subheadline).foregroundStyle(HeroColor.detail)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.horizontal, 20).padding(.top, textSize.isAccessibilitySize ? 20 : 8)
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
      .buttonStyle(PrimaryButtonStyle())
      // The label is explicit so the outgoing text, which lingers for the
      // cross-fade, never leaks into it.
      .accessibilityLabel(hero.action)
      .accessibilityValue(pending ? "Starting" : "")
      .accessibilityIdentifier("start-workout")
      .disabled(model.busy || pending)
      .padding(16)
      .background(HeroColor.ink)
      if textSize.isAccessibilitySize {
        // Keep the primary action above the fold on a compact phone at the
        // largest text size. Metadata stays readable below it, without capping type.
        Text(hero.detail).font(.subheadline).foregroundStyle(HeroColor.detail)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 20).padding(.bottom, 20)
      }
    }
    .background(HeroColor.ink)
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .formaAnimation(FormaMotion.reveal, value: model.activeWorkoutName)
  }

  private var brand: some View {
    HStack(spacing: 10) {
      FormaMark().fill(FormaTheme.ink).frame(width: 32, height: 32)
        .padding(4).background(FormaTheme.lime, in: RoundedRectangle(cornerRadius: 12))
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
  private let days = ["M", "T", "W", "T", "F", "S", "S"]
  private let fullDays = [
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
  ]

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
    VStack(alignment: .leading, spacing: 18) {
      SectionHeading(
        title: "A little, consistently.",
        detail: "\(week.count) / \(model.workspace?.profile.goal ?? 4) this week")
      if textSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(0..<7) { day in
            VStack(alignment: .leading, spacing: 4) {
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
            VStack(spacing: 10) {
              Text(days[day]).font(.caption.weight(isToday ? .heavy : .semibold))
                .foregroundStyle(isToday ? FormaTheme.primary : FormaTheme.secondary)
              ZStack {
                Circle().fill(trained ? FormaTheme.lime : FormaTheme.surface)
                Circle().strokeBorder(
                  scheduled ? FormaTheme.accent : FormaTheme.line,
                  style: StrokeStyle(
                    lineWidth: scheduled ? 1.5 : 1, dash: scheduled && !trained ? [3, 3] : []))
                if trained {
                  Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(
                    FormaTheme.ink
                  )
                  .transition(motion.transition(.scale(scale: 0.3).combined(with: .opacity)))
                } else if scheduled {
                  Circle().fill(FormaTheme.accent).frame(width: 5, height: 5)
                    .transition(.opacity)
                }
              }.frame(width: 34, height: 34)
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
