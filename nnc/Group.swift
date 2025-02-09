/// Empty protocol for other places to recognize AnyTensor and AnyGroup with dynamic dispatch.
public protocol DynamicGraph_AnyParameters {
}

/// Protocol for other places to recognize AnyTensor and AnyGroup with static dispatch.
public protocol DynamicGraph_Any: DynamicGraph_AnyParameters {
  var graph: DynamicGraph { get }
  var untyped: [DynamicGraph.AnyTensor] { get }
  var kind: DeviceKind { get }
  var shape: TensorShape { get }
  var format: TensorFormat { get }
  var strides: TensorShape { get }
  var isConstant: Bool { get }
  var requiresGrad: Bool { get set }
}

/// Protocol for group of tensors.
public protocol DynamicGraph_AnyGroup: DynamicGraph_Any {
}

extension Model.Parameters: DynamicGraph_AnyParameters {
}

extension DynamicGraph {

  public typealias AnyGroup = DynamicGraph_AnyGroup

  /// Type-aware group of tensors.
  public struct Group<Element: DynamicGraph.AnyTensor>: RandomAccessCollection {
    var underlyingArray: [Element]

    public typealias Element = Element
    public typealias Index = Int
    public typealias Indices = Range<Index>
    public typealias SubSequence = Array<Element>.SubSequence
    public var endIndex: Index { underlyingArray.endIndex }
    public var indices: Indices { underlyingArray.indices }
    public var startIndex: Index { underlyingArray.startIndex }
    public func formIndex(after i: inout Index) { underlyingArray.formIndex(after: &i) }
    public func formIndex(before i: inout Index) { underlyingArray.formIndex(before: &i) }
    public subscript(position: Index) -> Element { underlyingArray[position] }
    public subscript(x: Indices) -> SubSequence { underlyingArray[x] }

    public init(_ elements: Element...) {
      underlyingArray = elements
    }

    public init<OtherElement: DynamicGraph.AnyTensor>(_ otherGroup: Group<OtherElement>) {
      if let upcastUnderlyingArray = otherGroup.underlyingArray as? [Element] {
        underlyingArray = upcastUnderlyingArray
      } else {
        let otherUnderlyingArray = otherGroup.underlyingArray
        var underlyingArray = [Element]()
        underlyingArray.reserveCapacity(otherUnderlyingArray.count)
        for element in otherUnderlyingArray {
          underlyingArray.append(Element(element))
        }
        self.underlyingArray = underlyingArray
      }
    }

    public init(_ underlyingArray: [Element]) {
      self.underlyingArray = underlyingArray
    }
  }

}

extension DynamicGraph.Group: DynamicGraph.AnyGroup {
  public var untyped: [DynamicGraph.AnyTensor] { underlyingArray as [DynamicGraph.AnyTensor] }
  public var graph: DynamicGraph { underlyingArray[0].graph }
  public var kind: DeviceKind {
    let kind = underlyingArray[0].kind
    for tensor in underlyingArray {
      assert(kind == tensor.kind)
    }
    return kind
  }
  public var shape: TensorShape {
    let shape = underlyingArray[0].shape
    for tensor in underlyingArray {
      assert(shape == tensor.shape)
    }
    return shape
  }
  public var format: TensorFormat {
    let format = underlyingArray[0].format
    for tensor in underlyingArray {
      assert(format == tensor.format)
    }
    return format
  }
  public var strides: TensorShape {
    let strides = underlyingArray[0].strides
    for tensor in underlyingArray {
      assert(strides == tensor.strides)
    }
    return strides
  }
  var dataType: DataType {
    let dataType = underlyingArray[0].dataType
    for tensor in underlyingArray {
      assert(dataType == tensor.dataType)
    }
    return dataType
  }
  public var isConstant: Bool {
    let isConstant = underlyingArray[0].isConstant
    for tensor in underlyingArray {
      assert(isConstant == tensor.isConstant)
    }
    return isConstant
  }
  public var requiresGrad: Bool {
    get {
      let requiresGrad = underlyingArray[0].requiresGrad
      for tensor in underlyingArray {
        assert(requiresGrad == tensor.requiresGrad)
      }
      return requiresGrad
    }
    set(v) {
      for tensor in underlyingArray {
        tensor.requiresGrad = v
      }
    }
  }
}

extension DynamicGraph.Group where Element: DynamicGraph.AnyTensor {
  public func reshaped(
    format: TensorFormat, shape: TensorShape, offset: TensorShape? = nil,
    strides: TensorShape? = nil
  ) -> Self {
    return DynamicGraph.Group(
      underlyingArray.map {
        $0.reshaped(format: format, shape: shape, offset: offset, strides: strides)
      })
  }
  public func reshaped(
    _ shapeFormat: TensorShapeFormat, offset: TensorShape? = nil, strides: TensorShape? = nil
  ) -> Self {
    return reshaped(
      format: shapeFormat.format, shape: shapeFormat.shape, offset: offset,
      strides: strides)
  }
}
