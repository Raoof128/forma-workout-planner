/// Clears only the draft values included in a successful persistence response.
/// Capture the acknowledged dictionary before awaiting the save; edits that
/// arrive during that await stay pending, as do entirely new draft keys.
/// A failed save has no acknowledgement and must leave the drafts unchanged.
public func retainingUnacknowledgedDrafts<Key: Hashable, Value: Equatable>(
  _ current: [Key: Value], acknowledged: [Key: Value]
) -> [Key: Value] {
  current.filter { key, value in
    guard let saved = acknowledged[key] else { return true }
    return value != saved
  }
}
