import FORMACore
import FORMASurfaces
import Foundation

/// Reads the saved session into the plain values the Live Activity shows. The exercise on show is
/// the one the workout screen opens on (`WorkoutEngine.resumeIndex`), so the Lock Screen and the
/// app never disagree about where the person is.
enum WorkoutLiveActivityMapping {
  static func state(
    for session: WorkoutSession, exerciseName: (String) -> String?, now: Date
  ) -> WorkoutActivityState {
    let index = WorkoutEngine.resumeIndex(session)
    let entry = session.exercises.indices.contains(index) ? session.exercises[index] : nil
    let progress = entry.map(WorkoutEngine.setProgress) ?? (done: 0, total: 0)
    return WorkoutActivityState(
      .init(
        sessionID: session.id, title: session.name,
        exercise: entry.flatMap { exerciseName($0.exerciseId) }, exerciseIndex: index,
        exerciseCount: session.exercises.count, exerciseDoneSets: progress.done,
        exerciseSetCount: progress.total, doneSets: WorkoutEngine.completedSets(session),
        totalSets: WorkoutEngine.totalSets(session),
        startedAt: Date(timeIntervalSince1970: session.startedAt / 1_000),
        restEnd: session.restEnd.map { Date(timeIntervalSince1970: $0 / 1_000) },
        restPausedSeconds: session.restPaused, restSeconds: session.restSeconds),
      now: now)
  }
}
