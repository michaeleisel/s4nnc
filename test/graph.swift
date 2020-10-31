import XCTest
import nnc

final class GraphTests: XCTestCase {

  func testGEMM() throws {
    let dynamicGraph = DynamicGraph()
    let a0 = dynamicGraph.variable(Tensor<Float32>([1.1, 2.2], .NC(2, 1)))
    let a1 = dynamicGraph.variable(Tensor<Float32>([2.2, 3.3], .NC(1, 2)))
    let a2 = a0 * a1
    XCTAssertEqual(a2.rawValue.dimensions, [2, 2])
    XCTAssertEqual(a2.rawValue[0, 0], 1.1 * 2.2)
    XCTAssertEqual(a2.rawValue[0, 1], 1.1 * 3.3)
    XCTAssertEqual(a2.rawValue[1, 0], 2.2 * 2.2)
    XCTAssertEqual(a2.rawValue[1, 1], 2.2 * 3.3)
  }

  static let allTests = [
    ("testGEMM", testGEMM),
  ]
}
