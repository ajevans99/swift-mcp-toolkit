import Testing

@testable import SPMTemplate

struct SPMTemplateTests {
  @Test("greet returns greeting for provided name")
  func greet() async throws {
    let sut = SPMTemplate()
    #expect(sut.greet(name: "World") == "Hello, World!")
  }
}
