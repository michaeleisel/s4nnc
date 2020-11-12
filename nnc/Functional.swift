import C_nnc

/**
 * This protocol defines a generic constructs such that we can use DynamicGraph.AnyTensorGroup
 * to represent either a collection of tensors from multiple GPUs or one tensor.
 * It has a typed version DynamicGraph.TensorGroup to enforce type constraint.
 */

public protocol DynamicGraph_AnyTensorConvertible {
}

public protocol DynamicGraph_AnyTensor {
  static func upcasting(convertible: DynamicGraph_AnyTensorConvertible) -> DynamicGraph_AnyTensor
}

public protocol DynamicGraph_AnyTensorGroup: DynamicGraph_AnyTensorConvertible {
  associatedtype AnyTensor: DynamicGraph_AnyTensor
  static func exec(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [AnyTensor], outputSize: Int32, streamContext: StreamContext?) -> [AnyTensor]
  static func exec(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [AnyTensor], outputs: [AnyTensor], streamContext: StreamContext?)
  static func evaluate(model: OpaquePointer, isTest: Bool, inputs: [AnyTensor], outputSize: Int32, streamContext: StreamContext?) -> [AnyTensor]
}

public extension DynamicGraph {
  typealias AnyTensorGroup = DynamicGraph_AnyTensorGroup
}

extension DynamicGraph.AnyTensor: DynamicGraph_AnyTensor {
  public static func upcasting(convertible: DynamicGraph_AnyTensorConvertible) -> DynamicGraph_AnyTensor {
    fatalError("This will not be needed.")
  }
}

extension DynamicGraph.AnyTensor: DynamicGraph.AnyTensorGroup {

  public typealias AnyTensor = DynamicGraph.AnyTensor

  public static func exec(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [AnyTensor], outputSize: Int32, streamContext: StreamContext?) -> [AnyTensor] {
    assert(inputs.count > 0)
    let graph = inputs[0].graph
    for input in inputs {
      assert(input.graph === graph)
    }
    let _inputs: [ccv_nnc_tensor_variable_t?] = inputs.map { $0._tensor }
    let _outputs = UnsafeMutablePointer<ccv_nnc_tensor_variable_t?>.allocate(capacity: Int(outputSize))
    let outputs: [DynamicGraph.AnyTensor] = (0..<outputSize).map { _ in graph.variable() }
    for (i, variable) in outputs.enumerated() {
      (_outputs + i).initialize(to: variable._tensor)
    }
    let _graph = graph._graph
    let _streamContext = streamContext?._stream
    ccv_nnc_dynamic_graph_exec(_graph, cmd, hint, 0, _inputs, Int32(_inputs.count), _outputs, outputSize, 0, _streamContext)
    _outputs.deallocate()
    return outputs
  }

  public static func exec(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [AnyTensor], outputs: [AnyTensor], streamContext: StreamContext?) {
    assert(inputs.count > 0)
    let graph = inputs[0].graph
    for input in inputs {
      assert(input.graph === graph)
    }
    let _inputs: [ccv_nnc_tensor_variable_t?] = inputs.map { $0._tensor }
    let _outputs = UnsafeMutablePointer<ccv_nnc_tensor_variable_t?>.allocate(capacity: outputs.count)
    for (i, variable) in outputs.enumerated() {
      (_outputs + i).initialize(to: variable._tensor)
    }
    let _graph = graph._graph
    let _streamContext = streamContext?._stream
    ccv_nnc_dynamic_graph_exec(_graph, cmd, hint, 0, _inputs, Int32(_inputs.count), _outputs, Int32(outputs.count), 0, _streamContext)
    _outputs.deallocate()
  }

  public static func evaluate(model: OpaquePointer, isTest: Bool, inputs: [AnyTensor], outputSize: Int32, streamContext: StreamContext?) -> [AnyTensor] {
    assert(inputs.count > 0)
    let graph = inputs[0].graph
    for input in inputs {
      assert(input.graph === graph)
    }
    let _inputs: [ccv_nnc_tensor_variable_t?] = inputs.map { $0._tensor }
    let _outputs = UnsafeMutablePointer<ccv_nnc_tensor_variable_t?>.allocate(capacity: Int(outputSize))
    let outputs: [DynamicGraph.AnyTensor] = (0..<outputSize).map { _ in graph.variable() }
    for (i, variable) in outputs.enumerated() {
      assert(variable.graph === graph)
      (_outputs + i).initialize(to: variable._tensor)
    }
    let _graph = graph._graph
    let _streamContext = streamContext?._stream
    ccv_nnc_dynamic_graph_evaluate(_graph, model, isTest ? 1 : 0, _inputs, Int32(_inputs.count), _outputs, outputSize, nil, _streamContext)
    _outputs.deallocate()
    return outputs
  }

}

extension DynamicGraph.Group: DynamicGraph_AnyTensor where Element: DynamicGraph.AnyTensor {
  public static func upcasting(convertible: DynamicGraph_AnyTensorConvertible) -> DynamicGraph_AnyTensor {
    guard let convertible = convertible as? DynamicGraph.AnyGroup else {
      fatalError("This will not be needed.")
    }
    return DynamicGraph.Group<DynamicGraph.AnyTensor>(convertible.underlying)
  }
}

extension DynamicGraph.Group: DynamicGraph.AnyTensorGroup & DynamicGraph_AnyTensorConvertible where Element: DynamicGraph.AnyTensor {

  public typealias AnyTensor = DynamicGraph.Group<DynamicGraph.AnyTensor>

  public static func exec(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [AnyTensor], outputSize: Int32, streamContext: StreamContext?) -> [AnyTensor] {
    assert(inputs.count > 0)
    let graph = inputs[0][0].graph
    let parallel = inputs[0].count
    let inputSize = inputs.count
    var _inputs = [ccv_nnc_tensor_variable_t?](repeating: nil, count: parallel * inputSize)
    for (i, input) in inputs.enumerated() {
      assert(input.count == parallel)
      for (j, tensor) in input.enumerated() {
        assert(tensor.graph === graph)
        _inputs[j * inputSize + i] = tensor._tensor
      }
    }
    let _outputs = UnsafeMutablePointer<ccv_nnc_tensor_variable_t?>.allocate(capacity: Int(outputSize) * parallel)
    let outputs: [DynamicGraph.Group<DynamicGraph.AnyTensor>] = (0..<outputSize).map { _ in DynamicGraph.Group((0..<parallel).map { _ in graph.variable() }) }
    for (i, output) in outputs.enumerated() {
      for (j, tensor) in output.enumerated() {
        (_outputs + j * Int(outputSize) + i).initialize(to: tensor._tensor)
      }
    }
    let _graph = graph._graph
    let _streamContext = streamContext?._stream
    ccv_nnc_dynamic_graph_exec(_graph, cmd, hint, 0, _inputs, Int32(inputSize * parallel), _outputs, outputSize * Int32(parallel), Int32(parallel), _streamContext)
    _outputs.deallocate()
    return outputs
  }

  public static func exec(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [AnyTensor], outputs: [AnyTensor], streamContext: StreamContext?) {
    assert(inputs.count > 0)
    let graph = inputs[0][0].graph
    let parallel = inputs[0].count
    let inputSize = inputs.count
    var _inputs = [ccv_nnc_tensor_variable_t?](repeating: nil, count: parallel * inputSize)
    for (i, input) in inputs.enumerated() {
      assert(input.count == parallel)
      for (j, tensor) in input.enumerated() {
        assert(tensor.graph === graph)
        _inputs[j * inputSize + i] = tensor._tensor
      }
    }
    let outputSize = outputs.count
    let _outputs = UnsafeMutablePointer<ccv_nnc_tensor_variable_t?>.allocate(capacity: outputSize * parallel)
    for (i, output) in outputs.enumerated() {
      assert(output.count == parallel)
      for (j, tensor) in output.enumerated() {
        assert(tensor.graph === graph)
        (_outputs + j * outputSize + i).initialize(to: tensor._tensor)
      }
    }
    let _graph = graph._graph
    let _streamContext = streamContext?._stream
    ccv_nnc_dynamic_graph_exec(_graph, cmd, hint, 0, _inputs, Int32(inputSize * parallel), _outputs, Int32(outputSize * parallel), Int32(parallel), _streamContext)
    _outputs.deallocate()
  }

  public static func evaluate(model: OpaquePointer, isTest: Bool, inputs: [AnyTensor], outputSize: Int32, streamContext: StreamContext?) -> [AnyTensor] {
    assert(inputs.count > 0)
    assert(inputs.count > 0)
    let graph = inputs[0][0].graph
    let parallel = inputs[0].count
    let inputSize = inputs.count
    var _inputs = [ccv_nnc_tensor_variable_t?](repeating: nil, count: parallel * inputSize)
    for (i, input) in inputs.enumerated() {
      assert(input.count == parallel)
      for (j, tensor) in input.enumerated() {
        assert(tensor.graph === graph)
        _inputs[j * inputSize + i] = tensor._tensor
      }
    }
    ccv_cnnp_model_set_data_parallel(model, Int32(parallel))
    let _outputs = UnsafeMutablePointer<ccv_nnc_tensor_variable_t?>.allocate(capacity: Int(outputSize) * parallel)
    let outputs: [DynamicGraph.Group<DynamicGraph.AnyTensor>] = (0..<outputSize).map { _ in DynamicGraph.Group((0..<parallel).map { _ in graph.variable() }) }
    for (i, output) in outputs.enumerated() {
      for (j, tensor) in output.enumerated() {
        (_outputs + j * Int(outputSize) + i).initialize(to: tensor._tensor)
      }
    }
    let _graph = graph._graph
    let _streamContext = streamContext?._stream
    ccv_nnc_dynamic_graph_evaluate(_graph, model, isTest ? 1 : 0, _inputs, Int32(_inputs.count), _outputs, outputSize * Int32(parallel), nil, _streamContext)
    _outputs.deallocate()
    return outputs
  }

}

public protocol DynamicGraph_TensorGroup: DynamicGraph_AnyTensorGroup {
  associatedtype ElementNumeric: TensorNumeric
  init(_: AnyTensor)
}

public extension DynamicGraph {
  typealias TensorGroup = DynamicGraph_TensorGroup
}

public protocol _DynamicGraph_TensorGroup {
  associatedtype _Element: TensorNumeric
  init(_: DynamicGraph.AnyTensor)
}

extension DynamicGraph.Tensor: _DynamicGraph_TensorGroup {
  public typealias _Element = Element
}

extension DynamicGraph.Tensor: DynamicGraph.TensorGroup {
  public typealias ElementNumeric = Element
}

extension DynamicGraph.Group: DynamicGraph.TensorGroup where Element: _DynamicGraph_TensorGroup, Element: DynamicGraph.AnyTensor {
  public typealias ElementNumeric = Element._Element
}

public enum Functional {
  internal static func exec<T: DynamicGraph.AnyTensorGroup>(_: T.Type, cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [T.AnyTensor], outputSize: Int32, streamContext: StreamContext? = nil) -> [T.AnyTensor] {
    return T.exec(cmd: cmd, hint: hint, inputs: inputs, outputSize: outputSize, streamContext: streamContext)
  }
  static func exec<T: DynamicGraph.AnyTensorGroup>(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [T], outputSize: Int32, streamContext: StreamContext? = nil) -> [T.AnyTensor] {
    let tensorInputs: [T.AnyTensor]
    if let upcastTensorInputs = inputs as? [T.AnyTensor] {
      tensorInputs = upcastTensorInputs
    } else {
      tensorInputs = inputs.map { T.AnyTensor.upcasting(convertible: $0) as! T.AnyTensor }
    }
    return exec(T.self, cmd: cmd, hint: hint, inputs: tensorInputs, outputSize: outputSize, streamContext: streamContext)
  }
  internal static func exec<T: DynamicGraph.AnyTensorGroup>(_: T.Type, cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [T.AnyTensor], outputs: [T.AnyTensor], streamContext: StreamContext? = nil) {
    T.exec(cmd: cmd, hint: hint, inputs: inputs, outputs: outputs, streamContext: streamContext)
  }
  static func exec<T: DynamicGraph.AnyTensorGroup>(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [T], outputs: [T], streamContext: StreamContext? = nil) {
    let tensorInputs: [T.AnyTensor]
    if let upcastTensorInputs = inputs as? [T.AnyTensor] {
      tensorInputs = upcastTensorInputs
    } else {
      tensorInputs = inputs.map { T.AnyTensor.upcasting(convertible: $0) as! T.AnyTensor }
    }
    let tensorOutputs: [T.AnyTensor]
    if let upcastTensorOutputs = outputs as? [T.AnyTensor] {
      tensorOutputs = upcastTensorOutputs
    } else {
      tensorOutputs = outputs.map { T.AnyTensor.upcasting(convertible: $0) as! T.AnyTensor }
    }
    return exec(T.self, cmd: cmd, hint: hint, inputs: tensorInputs, outputs: tensorOutputs, streamContext: streamContext)
  }
}

public extension Model {
  internal func callAsFunction<T: DynamicGraph.AnyTensorGroup>(_: T.Type, _ inputs: [T.AnyTensor], streamContext: StreamContext? = nil) -> [T.AnyTensor] {
    let outputSize = ccv_cnnp_model_output_size(_model)
    return T.evaluate(model: _model, isTest: isTest, inputs: inputs, outputSize: outputSize, streamContext: streamContext)
  }
  func callAsFunction<T: DynamicGraph.AnyTensorGroup>(_ inputs: [T], streamContext: StreamContext? = nil) -> [T.AnyTensor] {
    let tensorInputs: [T.AnyTensor]
    if let upcastTensorInputs = inputs as? [T.AnyTensor] {
      tensorInputs = upcastTensorInputs
    } else {
      tensorInputs = inputs.map { T.AnyTensor.upcasting(convertible: $0) as! T.AnyTensor }
    }
    return self(T.self, tensorInputs, streamContext: streamContext)
  }
}

fileprivate extension AnyModelBuilder {
  func apply<U: DynamicGraph.AnyTensorGroup>(ofType: U.Type, _ t: Any, _ inputs: [U.AnyTensor], streamContext: StreamContext? = nil) -> [U.AnyTensor] {
    assert(inputs.count > 0)
    self.t = t
    self.inputs = (inputs as! [DynamicGraph_Any])
    let outputSize = self.outputSize
    let outputs = U.evaluate(model: model!._model, isTest: isTest, inputs: inputs, outputSize: Int32(outputSize), streamContext: streamContext)
    self.inputs = nil
    return outputs
  }
  func apply<U: DynamicGraph.AnyTensorGroup>(_ t: Any, _ inputs: [U], streamContext: StreamContext? = nil) -> [U.AnyTensor] {
    let tensorInputs: [U.AnyTensor]
    if let upcastTensorInputs = inputs as? [U.AnyTensor] {
      tensorInputs = upcastTensorInputs
    } else {
      tensorInputs = inputs.map { U.AnyTensor.upcasting(convertible: $0) as! U.AnyTensor }
    }
    return apply(ofType: U.self, t, tensorInputs, streamContext: streamContext)
  }
}

public extension ModelBuilder {
  func callAsFunction<U: DynamicGraph.AnyTensorGroup>(_ t: T, _ inputs: [U], streamContext: StreamContext? = nil) -> [U.AnyTensor] {
    return apply(t, inputs, streamContext: streamContext)
  }
}

public extension ModelBuilder where T == Void {
  func callAsFunction<U: DynamicGraph.AnyTensorGroup>(_ inputs: [U], streamContext: StreamContext? = nil) -> [U.AnyTensor] {
    return self(Void(), inputs, streamContext: streamContext)
  }
}
