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
}
