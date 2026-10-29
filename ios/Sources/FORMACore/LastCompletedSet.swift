extension WorkoutEngine {
  /// Searches sessions supplied newest first, preserving repeated exercise entries.
  public static func lastCompletedSet(
    for exerciseID: String, in sessions: [WorkoutSession], excluding sessionID: String? = nil
  ) -> LoggedSet? {
    for session in sessions where session.id != sessionID {
      for entry in session.exercises.reversed() where entry.exerciseId == exerciseID {
        if let set = entry.sets.last(where: \.done) { return set }
      }
    }
    return nil
  }
}
