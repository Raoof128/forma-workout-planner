import Foundation

/// The account's copy of the workspace, as `GET`/`PUT /api/workspace` return it.
public struct RemoteWorkspace: Equatable, Sendable {
  public var workspace: Workspace
  /// The server's own counter. It is not `workspace.revision`: the server
  /// rewrites the revision inside the data on every save and ignores the one it
  /// receives, and the local store keeps its own counting (see
  /// `WorkspaceStore.replaceWorkspace`). Only this value is ever sent back as
  /// `expectedRevision`.
  public var revision: Int
  public var updatedAt: String?

  public init(workspace: Workspace, revision: Int, updatedAt: String? = nil) {
    self.workspace = workspace
    self.revision = revision
    self.updatedAt = updatedAt
  }
}

/// One `PUT /api/workspace`. The payload is the stored workspace JSON as bytes,
/// never re-encoded, so a retry is byte-for-byte what the server saw before.
public struct WorkspacePut: Equatable, Sendable {
  public var operationId: String
  public var expectedRevision: Int
  public var payload: Data

  public init(operationId: String, expectedRevision: Int, payload: Data) {
    self.operationId = operationId
    self.expectedRevision = expectedRevision
    self.payload = payload
  }

  init(_ pending: PendingOperation) {
    self.init(
      operationId: pending.operationId, expectedRevision: pending.expectedRevision,
      payload: pending.payload)
  }

  /// `{"data":<payload>,"expectedRevision":N,"operationId":"…"}`, the body the
  /// route's strict schema accepts, with the payload spliced in untouched.
  public func requestBody() -> Data {
    var body = Data("{\"data\":".utf8)
    body.append(payload)
    body.append(Data(",\"expectedRevision\":\(expectedRevision),\"operationId\":".utf8))
    body.append(Data(Self.jsonString(operationId).utf8))
    body.append(Data("}".utf8))
    return body
  }

  private static func jsonString(_ value: String) -> String {
    var out = "\""
    for scalar in value.unicodeScalars {
      switch scalar {
      case "\"": out += "\\\""
      case "\\": out += "\\\\"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      default:
        if scalar.value < 0x20 {
          out += "\\u" + String(scalar.value, radix: 16).leftPaddedForJSON()
        } else {
          out.unicodeScalars.append(scalar)
        }
      }
    }
    return out + "\""
  }
}

extension String {
  fileprivate func leftPaddedForJSON() -> String {
    String(repeating: "0", count: Swift.max(0, 4 - count)) + self
  }
}

/// Why a request to the account did not produce an acknowledgement.
public enum WorkspaceTransportError: Error, Equatable, Sendable {
  /// 409 `stale_revision`: the account moved on. Carries its latest copy.
  case staleRevision(latest: RemoteWorkspace)
  /// 409 `account_changed`: the session no longer belongs to this member.
  case accountChanged
  /// 401.
  case unauthorized
  /// 409 `operation_id_reused`: the identifier was already used for different
  /// bytes. Retrying cannot help; the engine starts over with a fresh one.
  case operationReused
  /// 400/413: the account refused the payload itself.
  case invalid(String)
  /// 429 or an equivalent back-off request.
  case rateLimited(retryAfter: TimeInterval?)
  /// No connection, or the request never completed.
  case offline
  /// 5xx or another failure the same request may survive later.
  case transient(String)
}

/// The two calls the engine needs. The app supplies a URLSession-backed one
/// (cookies, native headers, the Access headers on staging); tests supply a fake.
public protocol WorkspaceTransport: Sendable {
  /// `GET /api/workspace`.
  func fetch() async throws -> RemoteWorkspace
  /// `PUT /api/workspace`. Returns the acknowledgement; throws
  /// `WorkspaceTransportError` for everything the server says no to.
  func put(_ request: WorkspacePut) async throws -> RemoteWorkspace
}

/// Reads the server's JSON into the engine's types, so the app's URLSession
/// transport is a thin shell and the mapping is covered by `swift test`.
public enum WorkspaceWire {
  private struct Envelope: Decodable {
    var data: Workspace
    var revision: Int
    var updatedAt: String?
  }

  /// Decodes `{data, revision, updatedAt}` from a 200 (GET, PUT) or 409 body.
  public static func decodeRemote(_ body: Data) throws -> RemoteWorkspace {
    guard body.count <= Workspace.maximumBytes + 4_096 else {
      throw FormaError.invalid("The account workspace is larger than the supported 20 MiB limit.")
    }
    let envelope: Envelope
    do { envelope = try JSONDecoder().decode(Envelope.self, from: body) } catch {
      throw FormaError.invalid("The account workspace response was incomplete.")
    }
    guard envelope.revision >= 0 else {
      throw FormaError.invalid("The account workspace response was incomplete.")
    }
    return RemoteWorkspace(
      workspace: envelope.data, revision: envelope.revision, updatedAt: envelope.updatedAt)
  }

  /// Maps a non-2xx response. `error` codes win over the status, as on the web:
  /// `account_changed` is recognised whatever status carries it.
  public static func transportError(
    status: Int, body: Data?, retryAfter: String? = nil
  ) -> WorkspaceTransportError {
    var code: String?
    var message: String?
    if let body, let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
      code = object["error"] as? String
      message = object["message"] as? String
    }
    if code == "account_changed" { return .accountChanged }
    switch status {
    case 401: return .unauthorized
    case 409:
      if code == "operation_id_reused" { return .operationReused }
      if let body, let latest = try? decodeRemote(body) { return .staleRevision(latest: latest) }
      // A conflict without the account's copy cannot be shown or resolved; a
      // fresh read will supply it.
      return .transient("The account reported a conflict without its latest copy.")
    case 400, 413, 422:
      return .invalid(message ?? "The account could not accept this training data.")
    case 429:
      return .rateLimited(retryAfter: retryAfter.flatMap { TimeInterval($0) })
    default:
      return .transient(message ?? "The account is unavailable (\(status)).")
    }
  }
}
