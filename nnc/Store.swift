import C_nnc
import SQLite3

extension DynamicGraph {

  final class _Store {
    let sqlite: UnsafeMutableRawPointer
    let flags: Store.OpenFlag
    init(sqlite: OpaquePointer, flags: Store.OpenFlag) {
      self.sqlite = UnsafeMutableRawPointer(sqlite)
      self.flags = flags
    }
    deinit {
      // If the database is opened with WAL mode, this makes sure everything write back to the main
      // database, much easier to operate without worrying the data left in the wal log.
      if flags.contains(.truncateWhenClose) {
        sqlite3_wal_checkpoint_v2(OpaquePointer(sqlite), nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
      }
      sqlite3_close(OpaquePointer(sqlite))
    }
  }

  /**
   * A key-value based parameter store.
   */
  public struct Store {
    public struct OpenFlag: OptionSet {
      public let rawValue: Int
      public init(rawValue: Int) {
        self.rawValue = rawValue
      }
      public static let truncateWhenClose = OpenFlag(rawValue: 1 << 0)
    }
    private let graph: DynamicGraph
    private let store: _Store

    /**
     * Read a type-erased tensor from the store.
     *
     * - Parameter key: The key corresponding to that particular tensor.
     */
    public func read(_ key: String) -> NNC.AnyTensor? {
      var underlying: UnsafeMutablePointer<ccv_nnc_tensor_t>? = nil
      let result = ccv_nnc_tensor_read(store.sqlite, key, &underlying)
      guard result == CCV_IO_FINAL else { return nil }
      let anyTensor = AnyTensorStorage(underlying!)
      return anyTensor.toAnyTensor()
    }

    /**
     * Read a tensor from the store into tensor variable from dynamic graph.
     *
     * - Parameters:
     *   - key: The key corresponding to that particular tensor.
     *   - variable: The tensor variable to be initialized with.
     * - Returns whether we successfully initialized the tensor variable.
     */
    @discardableResult
    public func read(_ key: String, variable: DynamicGraph_Any) -> Bool {
      switch variable {
      case let tensor as DynamicGraph.AnyTensor:
        assert(tensor.graph === graph)
        let _graph = graph.cGraph
        let _tensor = tensor._tensor
        let raw = ccv_nnc_tensor_from_variable_impl(_graph, _tensor, nil)
        if raw != nil {
          var underlying = raw
          let result = ccv_nnc_tensor_read(store.sqlite, key, &underlying)
          if result == CCV_IO_FINAL {
            assert(underlying == raw)
          }
          return result == CCV_IO_FINAL
        }
        var underlying: UnsafeMutablePointer<ccv_nnc_tensor_t>? = nil
        let result = ccv_nnc_tensor_read(store.sqlite, key, &underlying)
        guard result == CCV_IO_FINAL else { return false }
        let anyTensor = AnyTensorStorage(underlying!)
        ccv_nnc_tensor_variable_set(_graph, _tensor, underlying)
        // Retain the tensor until we freed the variable.
        ccv_nnc_tensor_variable_destructor_hook(
          _graph, _tensor,
          { _, _, ctx in
            // No longer need to retain the tensor.
            Unmanaged<NNC.AnyTensorStorage>.fromOpaque(ctx!).release()
          }, Unmanaged.passRetained(anyTensor).toOpaque())
      case let group as DynamicGraph.AnyGroup:
        for (i, tensor) in group.untyped.enumerated() {
          guard read("\(key)(\(i))", variable: tensor) else {
            return false
          }
        }
      default:
        fatalError("Cannot recognize the variable")
      }
      return true
    }
    /**
     * Read parameters into a given model.
     *
     * - Parameters:
     *   - key: The key corresponding to a particular model.
     *   - model: The model to be initialized with parameters from a given key.
     */
    public func read(_ key: String, model: Model) {
      ccv_cnnp_model_read(store.sqlite, key, model.cModel)
    }
    /**
     * Read parameters into a given model builder.
     *
     * - Parameters:
     *   - key: The key corresponding to a particular model.
     *   - model: The model builder to be initialized with parameters from a given key.
     */
    public func read(_ key: String, model: AnyModelBuilder) {
      model.read(key, from: store)
    }

    /**
     * Write a tensor to the store.
     *
     * - Parameters:
     *   - key: The key corresponding to a particular tensor.
     *   - tensor: The tensor to be persisted.
     */
    public func write(_ key: String, tensor: NNC.AnyTensor) {
      ccv_nnc_tensor_write(tensor.cTensor, store.sqlite, key)
    }
    /**
     * Write a tensor variable to the store.
     *
     * - Parameters:
     *   - key: The key corresponding to a particular tensor.
     *   - variable: The tensor variable to be persisted.
     */
    public func write(_ key: String, variable: DynamicGraph_Any) {
      switch variable {
      case let tensor as DynamicGraph.AnyTensor:
        assert(tensor.graph === graph)
        let _graph = graph.cGraph
        let _tensor = tensor._tensor
        let raw = ccv_nnc_tensor_from_variable_impl(_graph, _tensor, nil)!
        ccv_nnc_tensor_write(raw, store.sqlite, key)
      case let group as DynamicGraph.AnyGroup:
        for (i, tensor) in group.untyped.enumerated() {
          write("\(key)(\(i))", variable: tensor)
        }
      default:
        fatalError("Cannot recognize the variable")
      }
    }
    /**
     * Write a model to the store.
     *
     * - Parameters:
     *   - key: The key corresponding to a particular model.
     *   - model: The model where its parameters to be persisted.
     */
    public func write(_ key: String, model: Model) {
      ccv_cnnp_model_write(model.cModel, store.sqlite, key)
    }
    /**
     * Write a model builder to the store.
     *
     * - Parameters:
     *   - key: The key corresponding to a particular model builder.
     *   - model builder: The model where its parameters to be persisted.
     */
    public func write(_ key: String, model: AnyModelBuilder) {
      write(key, model: model.model!)
    }

    init(_ store: _Store, graph: DynamicGraph) {
      self.store = store
      self.graph = graph
    }

  }

  /**
   * Open the store from a file.
   *
   * - Parameters:
   *   - filePath: The file path for the store.
   *   - flags: The flags for the opening store. Default to truncateWhenClose.
   *   - procedure: When the store is open, you can access it from this closure.
   * - Returns: Wether this store can be successfully open or not.
   */
  @discardableResult
  public func openStore(
    _ filePath: String, flags: Store.OpenFlag = .truncateWhenClose,
    procedure: (_ store: Store) -> Void
  ) -> Bool {
    var _sqlite: OpaquePointer? = nil
    sqlite3_open_v2(filePath, &_sqlite, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
    guard let sqlite = _sqlite else { return false }
    let store = Store(_Store(sqlite: sqlite, flags: flags), graph: self)
    procedure(store)
    return true
  }

}
