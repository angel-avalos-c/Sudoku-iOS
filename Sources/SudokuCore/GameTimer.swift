/// A pauseable elapsed-time accumulator driven by caller-supplied timestamps.
///
/// Timestamps are measured in seconds on any monotonic or wall-clock basis;
/// callers own the clock source, which keeps timer calculations testable.
public struct GameTimer: Equatable, Sendable {
    public private(set) var elapsedSeconds: Double
    private var activeSince: Double?

    public init(elapsedSeconds: Double = 0) {
        self.elapsedSeconds = elapsedSeconds
        activeSince = nil
    }

    public var isRunning: Bool {
        activeSince != nil
    }

    public mutating func resume(at timestamp: Double) {
        guard activeSince == nil else { return }
        activeSince = timestamp
    }

    public mutating func update(at timestamp: Double) {
        guard let activeSince else { return }
        elapsedSeconds += max(0, timestamp - activeSince)
        self.activeSince = timestamp
    }

    public mutating func pause(at timestamp: Double) {
        update(at: timestamp)
        activeSince = nil
    }

    /// Stops the timer without accruing time beyond the last explicit update.
    public mutating func freeze() {
        activeSince = nil
    }

    public mutating func reset() {
        elapsedSeconds = 0
        activeSince = nil
    }
}
