import XCTest

@testable import FORMACore

final class ExerciseSearchTests: XCTestCase {
  private var exercise: Exercise {
    Exercise(
      id: "test", name: "Dumbbell chest press", muscle: "Chest", equipment: "Dumbbell",
      description: "", aliases: ["Développé couché"])
  }
  func testSearchCombinesWordsAcrossNameMuscleEquipmentAndAlias() {
    XCTAssertTrue(exercise.matches(query: "chest dumbbell"))
    XCTAssertTrue(exercise.matches(query: "couche chest"))
    XCTAssertTrue(exercise.matches(query: "  chest   press  "))
  }
  func testSearchFoldsDiacriticsCaseAndPunctuation() {
    XCTAssertTrue(exercise.matches(query: "DEVELOPPE"))
    XCTAssertTrue(exercise.matches(query: "dumb-bell"))
    XCTAssertTrue(exercise.matches(query: ""))
  }
  func testSearchRequiresEveryWord() {
    XCTAssertFalse(exercise.matches(query: "chest cable"))
    XCTAssertFalse(exercise.matches(query: "squat"))
  }

  func testNonemptyQueriesWithoutIndexedLettersDoNotMatchEveryExercise() {
    for query in ["胸", "عضلة", "мышца", "💪", "---", "chest 💪"] {
      XCTAssertFalse(exercise.matches(query: query), query)
    }
    XCTAssertTrue(exercise.matches(query: " \n\t "))
  }

  func testAsciiFoldFastPathEqualsTheUnicodeFoldForEveryAsciiScalar() {
    let all = String(String.UnicodeScalarView((0..<128).compactMap(Unicode.Scalar.init)))
    XCTAssertEqual(Exercise.fold(all), Exercise.foldUnicode(all))
    for value in 0..<128 {
      let text = "Ab" + String(Character(Unicode.Scalar(UInt8(value)))) + "Z9 q"
      XCTAssertEqual(Exercise.fold(text), Exercise.foldUnicode(text), "scalar \(value)")
    }
    for text in ["Dumbbell Chest-Press (45°)", "T-Bar Row", "", "  ", "ABC xyz 019"] {
      XCTAssertEqual(Exercise.fold(text), Exercise.foldUnicode(text), text)
    }
    XCTAssertEqual(
      Exercise.fold("Développé couché ß İ"), Exercise.foldUnicode("Développé couché ß İ"))
  }

  func testSearchKeyFollowsEditsToIndexedFields() {
    var edited = Exercise(
      id: "r", name: "Row", muscle: "Back", equipment: "Dumbbell", description: "")
    XCTAssertTrue(edited.matches(query: "dumbbell back"))
    edited.equipment = "Cable"
    XCTAssertFalse(edited.matches(query: "dumbbell"))
    XCTAssertTrue(edited.matches(query: "cable"))
    edited.aliases.append("Tirage poitrine")
    XCTAssertTrue(edited.matches(query: "poitrine"))
    edited.name = "Squat"
    XCTAssertFalse(edited.matches(query: "row"))
    XCTAssertTrue(edited.matches(query: "squat"))
    edited.muscle = "Quads"
    XCTAssertFalse(edited.matches(query: "back"))
    XCTAssertEqual(
      Exercise(id: "a", name: "X", muscle: "M", equipment: "E", description: ""),
      Exercise(id: "a", name: "X", muscle: "M", equipment: "E", description: ""))
  }

  func testBatchFilterEqualsPerExerciseMatchingInCatalogueOrder() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("FORMA/Resources/catalog.json")
    let catalog = try JSONDecoder().decode([Exercise].self, from: Data(contentsOf: url))
    for query in [
      "", "  ", "press", "Dumbbell chest", "DEVELOPPE", "bar-bell row", "zzzz", "💪", "a b c",
    ] {
      XCTAssertEqual(
        Exercise.filter(catalog, matching: query).map(\.id),
        catalog.filter { $0.matches(query: query) }.map(\.id), query)
    }
  }
}
