public final class TimeLimit<EnvType: Env> {
  private let env: EnvType
  private let maxEpisodeSteps: Int
  private var elapsedSteps: Int
  public init(env: EnvType, maxEpisodeSteps: Int) {
    self.env = env
    self.maxEpisodeSteps = maxEpisodeSteps
    self.elapsedSteps = 0
  }
}

extension TimeLimit: Env {
  public typealias ActType = EnvType.ActType
  public typealias ObsType = EnvType.ObsType

  public func step(action: ActType) -> (ObsType, Float, Bool, [String: Any]) {
    let result = env.step(action: action)
    var (_, _, done, info) = result
    elapsedSteps += 1
    if elapsedSteps >= maxEpisodeSteps {
      // TimeLimit.truncated key may have been already set by the environment
      // do not overwrite it
      let episodeTruncated = !done || (info["TimeLimit.truncated", default: false] as! Bool)
      info["TimeLimit.truncated"] = episodeTruncated
      done = true
    }
    return (result.0, result.1, done, info)
  }

  public func reset(seed: Int?) -> (ObsType, [String: Any]) {
    elapsedSteps = 0
    return env.reset(seed: seed)
  }

  public func render() {
    env.render()
  }
}
