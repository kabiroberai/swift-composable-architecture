import Perception

public struct ObservationStateRegistrar: Sendable {
  public var id = ObservableStateID()
  private let registrar = PerceptionRegistrar()

  public init() {}

  public func beginMutation<Subject: Perceptible, Member>(
    of subject: inout Subject,
    keyPath: KeyPath<Subject, Member>,
    storageKeyPath: WritableKeyPath<Subject, Member>
  ) -> (inout Subject) -> Void {
    guard var oldValue = subject[keyPath: storageKeyPath] as? any ObservableState else {
      willSet(subject, keyPath: keyPath)
      return { didSet($0, keyPath: keyPath) }
    }

    let oldID = oldValue._$id
    // create a new ephemeral ID before mutation. If the returned object
    // has the same ID, it must be a modified version of the existing object,
    // which means there was a synchronous mutation that fired observers.
    // If the ID is different, all bets are off since the returned object
    // could have been modified at some arbitrary point in time.
    oldValue._$id = .init()
    subject[keyPath: storageKeyPath] = oldValue as! Member
    return { subject in
      if var newValue = subject[keyPath: storageKeyPath] as? any ObservableState,
         _$isIdentityEqual(oldValue, newValue) {
        newValue._$id = oldID
        subject[keyPath: storageKeyPath] = newValue as! Member
        return
      }
      let newValue = subject[keyPath: storageKeyPath]
      oldValue._$id = oldID
      subject[keyPath: storageKeyPath] = oldValue as! Member
      withMutation(of: subject, keyPath: keyPath) {
        subject[keyPath: storageKeyPath] = newValue
      }
    }
  }
}

extension ObservationStateRegistrar: Equatable, Hashable, Codable {
  public static func == (_: Self, _: Self) -> Bool { true }
  public func hash(into hasher: inout Hasher) {}
  public init(from decoder: Decoder) throws { self.init() }
  public func encode(to encoder: Encoder) throws {}
}

#if canImport(Observation)
  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension ObservationStateRegistrar {
    public func access<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.access(subject, keyPath: keyPath)
    }

    public func withMutation<Subject: Observable, Member, T>(
      of subject: Subject, keyPath: KeyPath<Subject, Member>, _ mutation: () throws -> T
    ) rethrows -> T {
      try self.registrar.withMutation(of: subject, keyPath: keyPath, mutation)
    }
    public func willSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.willSet(subject, keyPath: keyPath)
    }
    public func didSet<Subject: Observable, Member>(
      _ subject: Subject, keyPath: KeyPath<Subject, Member>
    ) {
      self.registrar.didSet(subject, keyPath: keyPath)
    }
  }
#endif

extension ObservationStateRegistrar {
  @_disfavoredOverload
  public func access<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    self.registrar.access(subject, keyPath: keyPath)
  }

  @_disfavoredOverload
  public func withMutation<Subject: Perceptible, Member, T>(
    of subject: Subject,
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    try self.registrar.withMutation(of: subject, keyPath: keyPath, mutation)
  }
  @_disfavoredOverload
  public func willSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    self.registrar.willSet(subject, keyPath: keyPath)
  }
  @_disfavoredOverload
  public func didSet<Subject: Perceptible, Member>(
    _ subject: Subject,
    keyPath: KeyPath<Subject, Member>
  ) {
    self.registrar.didSet(subject, keyPath: keyPath)
  }
}
