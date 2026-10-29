import AVKit
import FORMACore
import SwiftUI
import UIKit

/// The website's exercise media, bundled offline by scripts/build-ios-media.py:
/// FORMA's own illustration sheets (one cell per exercise) and public-domain or
/// CC BY demo clips with their credits. `Media/media.json` is the index.
struct ExerciseMediaLibrary: Decodable, Sendable {
  struct Illustration: Decodable, Sendable {
    let sheet: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let title: String
    let equipment: Bool
    let caption: String
  }

  struct Sheet: Decodable, Sendable {
    let width: Double
    let height: Double
  }

  struct Clip: Decodable, Sendable {
    let width: Double
    let height: Double
    let source: String
    let title: String
    let author: String
    let url: String
  }

  struct Demo: Decodable, Sendable {
    let clip: String
    let caption: String
  }

  struct Source: Decodable, Sendable {
    let name: String
    let license: String
    let licenseUrl: String
    let notice: String
  }

  let sheets: [String: Sheet]
  let images: [String: Illustration]
  let clips: [String: Clip]
  let demos: [String: Demo]
  let sources: [String: Source]

  static let empty = ExerciseMediaLibrary(
    sheets: [:], images: [:], clips: [:], demos: [:], sources: [:])

  /// Read once, on first use. A missing or unreadable index means no media,
  /// never a crash: the guide still has its text.
  static let shared: ExerciseMediaLibrary = {
    guard
      let url = Bundle.main.url(forResource: "media", withExtension: "json", subdirectory: "Media"),
      let data = try? Data(contentsOf: url),
      let library = try? JSONDecoder().decode(ExerciseMediaLibrary.self, from: data)
    else { return .empty }
    return library
  }()

  static func url(_ name: String, _ ext: String, in folder: String) -> URL? {
    Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Media/\(folder)")
  }
}

/// Crops one illustration out of its sheet off the main thread and keeps the
/// result, so revisiting a guide shows it at once. The cache is main-actor
/// state; only the decode and crop run elsewhere.
@MainActor
enum ExerciseIllustrationLoader {
  private static let cache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 40
    return cache
  }()

  static func cached(_ id: String) -> UIImage? { cache.object(forKey: id as NSString) }

  static func load(_ id: String, _ illustration: ExerciseMediaLibrary.Illustration) async
    -> UIImage?
  {
    if let image = cached(id) { return image }
    let sheet = ExerciseMediaLibrary.shared.sheets[illustration.sheet]
    let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
      guard let url = ExerciseMediaLibrary.url(illustration.sheet, "heic", in: "sheets"),
        let source = UIImage(contentsOfFile: url.path)?.cgImage
      else { return nil }
      // The crop is in the catalogue's pixel space; scale it to the bundled sheet.
      let scaleX = Double(source.width) / (sheet?.width ?? Double(source.width))
      let scaleY = Double(source.height) / (sheet?.height ?? Double(source.height))
      let rect = CGRect(
        x: illustration.x * scaleX, y: illustration.y * scaleY,
        width: illustration.width * scaleX, height: illustration.height * scaleY
      ).integral
      guard let cell = source.cropping(to: rect) else { return nil }
      return UIImage(cgImage: cell)
    }.value
    if let image { cache.setObject(image, forKey: id as NSString) }
    return image
  }
}

/// The guide's pictures: FORMA's illustration of the movement and, where the
/// website has one, a short demo clip that plays muted on request.
struct ExerciseMediaSection: View {
  let exercise: Exercise
  private var library: ExerciseMediaLibrary { .shared }

  var body: some View {
    if let illustration = library.images[exercise.id] {
      Section {
        ExerciseIllustration(
          id: exercise.id, name: exercise.name, illustration: illustration)
      }
    }
    if let demo = library.demos[exercise.id], let clip = library.clips[demo.clip] {
      Section("Watch it") {
        ExerciseDemoClip(
          clipID: demo.clip, clip: clip, caption: demo.caption,
          source: library.sources[clip.source])
      }
    }
  }
}

private struct ExerciseIllustration: View {
  @Environment(\.formaMotion) private var motion
  let id: String
  let name: String
  let illustration: ExerciseMediaLibrary.Illustration
  @State private var image: UIImage?
  @State private var failed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack {
        // The sheets are drawn on white, so the frame is white in both
        // appearances and the drawing never sits on a dark box edge.
        RoundedRectangle(cornerRadius: FormaRadius.card).fill(Color.white)
        if let image {
          Image(uiImage: image).resizable().scaledToFit()
            .transition(motion.transition(.opacity))
        } else if failed {
          Label("Image unavailable", systemImage: "photo")
            .font(.footnote).foregroundStyle(Color.black.opacity(0.55))
        } else {
          ProgressView().tint(Color.black.opacity(0.5))
        }
      }
      .aspectRatio(illustration.width / max(1, illustration.height), contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card))
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isImage)
      .accessibilityLabel(
        "\(illustration.equipment ? "Equipment" : "Exercise") illustration for \(name): \(illustration.title)"
      )
      if !illustration.caption.isEmpty {
        Text(illustration.caption).font(.footnote).foregroundStyle(FormaTheme.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    .task(id: id) {
      if let cached = ExerciseIllustrationLoader.cached(id) {
        image = cached
        return
      }
      let loaded = await ExerciseIllustrationLoader.load(id, illustration)
      withFormaAnimation(motion, FormaMotion.reveal) {
        image = loaded
        failed = loaded == nil
      }
    }
  }
}

/// A demo clip: the poster until the person presses play, then a muted,
/// looping player with the system controls. Nothing plays by itself.
private struct ExerciseDemoClip: View {
  let clipID: String
  let clip: ExerciseMediaLibrary.Clip
  let caption: String
  let source: ExerciseMediaLibrary.Source?
  @State private var player: AVQueuePlayer?
  @State private var looper: AVPlayerLooper?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack {
        if let player {
          VideoPlayer(player: player)
        } else {
          poster
          Button(action: play) {
            Image(systemName: "play.fill").font(.title2.weight(.bold))
              .foregroundStyle(FormaTheme.ink)
              .frame(width: 64, height: 64)
              .background(FormaTheme.lime, in: Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Play demo: \(caption.isEmpty ? clip.title : caption)")
          .accessibilityHint("Plays without sound and repeats.")
        }
      }
      .aspectRatio(clip.width / max(1, clip.height), contentMode: .fit)
      .background(Color.black)
      .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card))
      if !caption.isEmpty {
        Text(caption).font(.footnote).foregroundStyle(FormaTheme.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      credit
    }
    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    .onDisappear {
      player?.pause()
      player = nil
      looper = nil
    }
  }

  @ViewBuilder private var poster: some View {
    if let url = ExerciseMediaLibrary.url(clipID, "jpg", in: "demos"),
      let image = UIImage(contentsOfFile: url.path)
    {
      Image(uiImage: image).resizable().scaledToFill().accessibilityHidden(true)
    }
  }

  @ViewBuilder private var credit: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(clip.author.isEmpty ? (source?.name ?? "") : clip.author)
        .font(.footnote.weight(.semibold))
      if let source {
        if let url = URL(string: source.licenseUrl), url.scheme == "https" {
          Link(source.license, destination: url).font(.footnote)
        } else {
          Text(source.license).font(.footnote)
        }
        if !source.notice.isEmpty {
          Text(source.notice).font(.caption).foregroundStyle(FormaTheme.secondary)
        }
      }
      if let url = URL(string: clip.url), url.scheme == "https" {
        Link("Original video", destination: url).font(.footnote)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private func play() {
    guard let url = ExerciseMediaLibrary.url(clipID, "mp4", in: "demos") else { return }
    let queue = AVQueuePlayer()
    queue.isMuted = true
    // Mixes with whatever the person is listening to rather than stopping it.
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
    player = queue
    queue.play()
  }
}
