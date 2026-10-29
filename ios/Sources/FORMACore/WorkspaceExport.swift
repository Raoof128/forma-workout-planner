import Foundation

/// Exports the acknowledged canonical workspace using the same compact byte
/// budget as local persistence and the existing web backup reader.
public enum WorkspaceExport {
  public static func encode(_ workspace: Workspace) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(workspace)
    guard data.count <= Workspace.maximumBytes else {
      throw FormaError.invalid("This training backup is larger than the supported 20 MiB limit.")
    }
    return data
  }
}
