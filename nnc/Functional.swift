import C_nnc

public enum Functional {
  static func exec(cmd: ccv_nnc_cmd_t, hint: ccv_nnc_hint_t, inputs: [DynamicGraph.AnyTensor], outputSize: Int32, streamContext: StreamContext? = nil) -> [DynamicGraph.AnyTensor] {
    assert(inputs.count > 0)
    let graph = inputs[0].graph
    for input in inputs {
      assert(ObjectIdentifier(input.graph) == ObjectIdentifier(graph))
    }
    let _inputs: [ccv_nnc_tensor_variable_t?] = inputs.map { $0._tensor }
    let _outputs = UnsafeMutablePointer<ccv_nnc_tensor_variable_t?>.allocate(capacity: Int(outputSize))
    let outputs: [DynamicGraph.AnyTensor] = (0..<outputSize).map { _ in graph.variable() }
    for (i, variable) in outputs.enumerated() {
      (_outputs + Int(i)).initialize(to: variable._tensor)
    }
    let _graph = graph._graph
    let _streamContext = streamContext?._stream
    ccv_nnc_dynamic_graph_exec(_graph, cmd, hint, 0, _inputs, Int32(_inputs.count), _outputs, outputSize, 0, _streamContext)
    _outputs.deallocate()
    return outputs
  }
}

public extension Functional {
  static func mul<Element>(left: DynamicGraph.Tensor<Element>, right: DynamicGraph.Tensor<Element>, scalar: Float32 = 1, streamContext: StreamContext? = nil) -> DynamicGraph.Tensor<Element> {
    var params = ccv_nnc_cmd_param_t()
    params.size.dim = (1, 1, 1, 0, 0, 0, 0, 0)
    params.blas.a = (scalar, 0, 0)
    let cmd = ccv_nnc_cmd(CCV_NNC_MUL_FORWARD, nil, params, 0)
    let outputs = exec(cmd: cmd, hint: ccv_nnc_no_hint, inputs: [left, right], outputSize: 1, streamContext: streamContext)
    return DynamicGraph.Tensor<Element>(outputs[0])
  }

  // Element-wise addition
  static func add<Element>(left: DynamicGraph.Tensor<Element>, right: DynamicGraph.Tensor<Element>, leftScalar: Float32 = 1, rightScalar: Float32 = 1, streamContext: StreamContext? = nil) -> DynamicGraph.Tensor<Element> {
    var params = ccv_nnc_cmd_param_t()
    params.size.dim = (1, 1, 1, 0, 0, 0, 0, 0)
    params.blas.a = (leftScalar, rightScalar, 0)
    let cmd = ccv_nnc_cmd(CCV_NNC_ADD_FORWARD, nil, params, 0)
    let outputs = exec(cmd: cmd, hint: ccv_nnc_no_hint, inputs: [left, right], outputSize: 1, streamContext: streamContext)
    return DynamicGraph.Tensor<Element>(outputs[0])
  }

  // Matrix multiplication
  static func matmul<Element>(left: DynamicGraph.Tensor<Element>, right: DynamicGraph.Tensor<Element>, leftTranspose: (Int, Int) = (0, 0), rightTranspose: (Int, Int) = (0, 0), streamContext: StreamContext? = nil) -> DynamicGraph.Tensor<Element> {
    var params = ccv_nnc_cmd_param_t()
    params.size.dim = (1, 1, 1, 0, 0, 0, 0, 0)
    params.blas.a = (1, 1, 0)
    params.blas.transpose_a = (Int32(leftTranspose.0), Int32(leftTranspose.1))
    params.blas.transpose_b = (Int32(rightTranspose.0), Int32(rightTranspose.1))
    let cmd = ccv_nnc_cmd(CCV_NNC_GEMM_FORWARD, nil, params, 0)
    let outputs = exec(cmd: cmd, hint: ccv_nnc_no_hint, inputs: [left, right], outputSize: 1, streamContext: streamContext)
    return DynamicGraph.Tensor<Element>(outputs[0])
  }
}
