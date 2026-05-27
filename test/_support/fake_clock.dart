/// Manual clock for deterministic time-dependent tests.
class FakeClock {
  /// Creates a [FakeClock] anchored at [now].
  FakeClock(this.now);

  /// Current value returned by [call]. Mutate via [advance].
  DateTime now;

  /// Advances [now] by [d].
  void advance(Duration d) {
    now = now.add(d);
  }

  /// Returns the current value — `DateTime Function()` shape.
  DateTime call() => now;
}
