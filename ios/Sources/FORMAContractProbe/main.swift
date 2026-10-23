import FORMACore
import Foundation

/// Development-only cross-language evidence. This target is not linked into the
/// iPhone application and reads only bundled/synthetic local resources.
@main
struct FORMAContractProbe {
  static func main() throws {
    let arguments = CommandLine.arguments
    guard arguments.count == 3 else {
      throw ProbeFailure("Usage: FORMAContractProbe REPOSITORY_ROOT OUTPUT_JSON_PATH")
    }
    let root = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let output = URL(fileURLWithPath: arguments[2])
    let decoder = JSONDecoder()
    let catalog = try decoder.decode(
      [Exercise].self,
      from: Data(contentsOf: root.appendingPathComponent("ios/FORMA/Resources/catalog.json")))
    let seed = try decoder.decode(
      Workspace.self,
      from: Data(contentsOf: root.appendingPathComponent("ios/FORMA/Resources/seed-workspace.json"))
    )
    try seed.validate(catalog: catalog)
    var cases: [NativeCase] = []
    for exercise in catalog {
      let d = exercise.defaults
      let routine = Routine(
        id: "synthetic-native-\(exercise.id)", name: "Synthetic native contract",
        exercises: [
          Prescription(
            exerciseId: exercise.id, sets: d.sets, reps: d.reps, weight: d.weight,
            durationSeconds: d.durationSeconds, distanceMeters: d.distanceMeters, perSide: d.perSide
          )
        ])
      var workspace = seed
      workspace.routines.append(routine)
      workspace.active = try WorkoutEngine.start(
        routine: routine, now: 1_792_440_000_000, catalog: catalog)
      workspace.active?.id = "synthetic-native-session-\(exercise.id)"
      workspace = try WorkoutEngine.toggleSet(
        in: workspace, entryIndex: 0, setIndex: 0, now: 1_792_440_001_000, catalog: catalog)
      workspace = try WorkoutEngine.finish(workspace, now: 1_792_440_060_000, catalog: catalog)
      cases.append(NativeCase(id: exercise.id, workspace: workspace))
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(
      NativeEvidence(
        synthetic: true, generator: "FORMACore Swift start/toggleSet/finish", cases: cases)
    ).write(to: output, options: .atomic)
    print("Wrote \(cases.count) native-generated contract cases.")
  }
}

private struct NativeCase: Encodable {
  var id: String
  var workspace: Workspace
}
private struct NativeEvidence: Encodable {
  var synthetic: Bool
  var generator: String
  var cases: [NativeCase]
}
private struct ProbeFailure: LocalizedError {
  var message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}
