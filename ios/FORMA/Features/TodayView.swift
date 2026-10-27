import FORMACore
import SwiftUI

/// Hero colours are fixed, so build each `UIColor` once instead of per render.
private enum HeroColor {
  static let ink = Color(hex: 0x151A17)
  static let scrim = Color(hex: 0x151A17).opacity(0.95)
  static let detail = Color(hex: 0xDEE5DC)
}

struct TodayView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    // `model.routines` filters the whole routine list on every read. Read it
    // once per render rather than five times (once per row for its number).
    let routines = model.routines
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
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

        VStack(alignment: .leading, spacing: 6) {
          Text("MAKE ROOM FOR").font(.caption.weight(.bold)).tracking(2).foregroundStyle(
            FormaTheme.secondary)
          EditorialTitle(text: "Your next stronger.")
        }

        if let active = model.workspace?.active {
          trainingHero(
            name: active.name, detail: "Pick up exactly where you left off.",
            action: "Resume workout", symbol: "play.fill", inProgress: true
          ) {
            model.receipt = nil
            model.workoutPresented = true
          }
        } else if let routine = routines.first {
          trainingHero(
            name: routine.name,
            detail: "\(routine.exercises.count) exercises · about \(routine.minutes) min",
            action: "Start workout", symbol: "arrow.up.right"
          ) {
            Task { await model.requestStart(routine) }
          }
        } else {
          ContentUnavailableView {
            Label("Your training starts here", systemImage: "dumbbell")
          } description: {
            Text("Create a routine in Plan, then make it yours one set at a time.")
          }
        }

        WeekStrip()

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
            .buttonStyle(.plain)
            Divider().overlay(FormaTheme.line)
          }
        }

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
          }
        } else {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkle").foregroundStyle(FormaTheme.accent)
            Text("A fresh page. Your first completed workout will appear here.")
              .font(.subheadline).foregroundStyle(FormaTheme.secondary)
          }
        }
        LocalSaveStatus(saving: model.busy)
      }
      .padding(24)
    }
    .background(FormaTheme.canvas)
    .toolbar(.hidden, for: .navigationBar)
  }

  private func trainingHero(
    name: String, detail: String, action: String, symbol: String, inProgress: Bool = false,
    perform: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .bottomLeading) {
        GeometryReader { geometry in
          Image("TrainingEditorial").resizable().scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .accessibilityHidden(true)
        LinearGradient(
          colors: [.clear, HeroColor.scrim], startPoint: .top, endPoint: .bottom)
        VStack(alignment: .leading, spacing: 10) {
          Label(
            inProgress ? "IN PROGRESS" : "YOUR NEXT SESSION",
            systemImage: inProgress ? "play.circle" : "arrow.turn.down.right"
          )
          .font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(FormaTheme.lime)
          Text(name).font(.system(.largeTitle, design: .default, weight: .black).width(.condensed))
            .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
          Text(detail).font(.subheadline).foregroundStyle(HeroColor.detail)
        }
        .padding(24)
      }
      .frame(minHeight: 290)
      Button(action: perform) {
        HStack {
          Text(action)
          Spacer()
          Image(systemName: symbol)
        }
      }
      .buttonStyle(PrimaryButtonStyle())
      .accessibilityIdentifier("start-workout")
      .disabled(model.busy)
      .padding(16)
      .background(HeroColor.ink)
    }
    .clipShape(RoundedRectangle(cornerRadius: 24))
  }

  private var brand: some View {
    HStack(spacing: 10) {
      FormaMark().fill(FormaTheme.ink).frame(width: 32, height: 32)
        .padding(4).background(FormaTheme.lime, in: RoundedRectangle(cornerRadius: 12))
      Text("FORMA").font(.title3.weight(.black)).tracking(3).foregroundStyle(FormaTheme.primary)
    }.fixedSize()
  }
  private var date: some View {
    Text(TrainingDate.label(.now, template: "EEE d MMM"))
      .font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.secondary)
  }
}

struct WeekStrip: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var textSize
  private let days = ["M", "T", "W", "T", "F", "S", "S"]
  private let fullDays = [
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
  ]

  /// Sessions and weekdays (Monday = 0) completed this week. `model.history`
  /// is sorted newest first, so stop at the first session before this week
  /// instead of parsing every saved date (up to 10,000) on each render.
  private func thisWeek() -> (count: Int, days: Set<Int>) {
    guard let interval = TrainingDate.calendar.dateInterval(of: .weekOfYear, for: .now) else {
      return (0, [])
    }
    var count = 0
    var days = Set<Int>()
    for session in model.history {
      let date = TrainingDate.date(session)
      if date < interval.start { break }
      guard interval.contains(date) else { continue }
      count += 1
      days.insert((TrainingDate.calendar.component(.weekday, from: date) + 5) % 7)
    }
    return (count, days)
  }

  var body: some View {
    let week = thisWeek()
    let completedDays = week.days
    let schedule = model.workspace?.schedule ?? []
    VStack(alignment: .leading, spacing: 18) {
      SectionHeading(
        title: "A little, consistently.",
        detail: "\(week.count) / \(model.workspace?.profile.goal ?? 4) this week")
      if textSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(0..<7) { day in
            VStack(alignment: .leading, spacing: 4) {
              Text(fullDays[day]).font(.headline)
              Text(
                completedDays.contains(day)
                  ? "Workout completed"
                  : schedule.contains(day)
                    ? "Planned training day" : "No workout recorded"
              )
              .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            }.accessibilityElement(children: .combine)
          }
        }
      } else {
        HStack(spacing: 0) {
          ForEach(0..<7) { day in
            let trained = completedDays.contains(day)
            let scheduled = schedule.contains(day)
            VStack(spacing: 10) {
              Text(days[day]).font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.secondary)
              ZStack {
                Circle().fill(trained ? FormaTheme.lime : FormaTheme.surface)
                Circle().strokeBorder(
                  scheduled ? FormaTheme.accent : FormaTheme.line,
                  style: StrokeStyle(
                    lineWidth: scheduled ? 1.5 : 1, dash: scheduled && !trained ? [3, 3] : []))
                if trained {
                  Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(
                    FormaTheme.ink)
                } else if scheduled {
                  Circle().fill(FormaTheme.accent).frame(width: 5, height: 5)
                }
              }.frame(width: 34, height: 34)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
              "\(fullDays[day]), \(trained ? "workout completed" : scheduled ? "planned training day" : "no workout recorded")"
            )
          }
        }
      }
      if !textSize.isAccessibilitySize {
        Text("Dashed circles are planned days. Checks are completed workouts.")
          .font(.caption).foregroundStyle(FormaTheme.secondary)
      }
    }
  }
}
