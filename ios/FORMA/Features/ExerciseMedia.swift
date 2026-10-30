import AVKit
import FORMACore
import ImageIO
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

  /// A website demonstration recorded as video, with its still start pose.
  struct Animation: Decodable, Sendable {
    let seconds: Double
    let description: String
    let width: Double
    let height: Double
  }

  struct Photo: Decodable, Sendable {
    let file: String
    var focusY: Double? = nil
  }

  struct Photos: Decodable, Sendable {
    let hero: Photo
    let routines: [Photo]
  }

  let sheets: [String: Sheet]
  let images: [String: Illustration]
  let clips: [String: Clip]
  let demos: [String: Demo]
  let sources: [String: Source]
  let animations: [String: Animation]
  let photos: Photos?

  static let empty = ExerciseMediaLibrary(
    sheets: [:], images: [:], clips: [:], demos: [:], sources: [:], animations: [:], photos: nil)

  /// The routine photo for a routine's `image` index, wrapping like the web.
  func routinePhoto(_ index: Int) -> Photo? {
    guard let routines = photos?.routines, !routines.isEmpty else { return nil }
    return routines[((index % routines.count) + routines.count) % routines.count]
  }

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

/// Decodes the bundled HEIC pictures one at a time, completely, off the main
/// thread. A `UIImage(contentsOfFile:)` stays undecoded until it is drawn, and
/// `preparingForDisplay()` may return nil, which left the decode to the main
/// thread at draw time: on the CI simulator three routine photos decoding at
/// once that way never finished and the app stopped answering. Every picture
/// leaves here as a plain bitmap, so drawing it never decodes anything.
actor MediaDecoder {
  static let shared = MediaDecoder()

  /// The picture at `url`, cut to `crop(size)` when given, as a decoded bitmap.
  func decode(_ url: URL, crop: (@Sendable (CGSize) -> CGRect)? = nil) -> UIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let full = CGImageSourceCreateImageAtIndex(
        source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    else { return nil }
    var picture = full
    if let crop {
      let rect = crop(CGSize(width: full.width, height: full.height))
      guard let cell = full.cropping(to: rect) else { return nil }
      picture = cell
    }
    // Redrawn into its own buffer: decoded for certain, and a cropped cell no
    // longer keeps its whole sheet in memory.
    guard
      let context = CGContext(
        data: nil, width: picture.width, height: picture.height, bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
          | CGBitmapInfo.byteOrder32Little.rawValue)
    else { return nil }
    context.draw(picture, in: CGRect(x: 0, y: 0, width: picture.width, height: picture.height))
    return context.makeImage().map { UIImage(cgImage: $0) }
  }
}

/// Crops one illustration out of its sheet and keeps the result, so revisiting
/// a guide shows it at once. The cache is main-actor state; the decode and
/// crop run in `MediaDecoder`.
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
    guard let url = ExerciseMediaLibrary.url(illustration.sheet, "heic", in: "sheets") else {
      return nil
    }
    let image = await MediaDecoder.shared.decode(url) { size in
      // The crop is in the catalogue's pixel space; scale it to the bundled sheet.
      let scaleX = size.width / (sheet?.width ?? size.width)
      let scaleY = size.height / (sheet?.height ?? size.height)
      return CGRect(
        x: illustration.x * scaleX, y: illustration.y * scaleY,
        width: illustration.width * scaleX, height: illustration.height * scaleY
      ).integral
    }
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
    if let animation = library.animations[exercise.id] {
      Section("See the movement") {
        ExerciseAnimationPlayer(id: exercise.id, name: exercise.name, animation: animation)
      }
    }
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

/// A website demonstration, recorded frame for frame from its SVG. It loops
/// silently like the web and starts on its still pose when motion is reduced;
/// a Pause/Play control is always there, because it repeats.
private struct ExerciseAnimationPlayer: View {
  @Environment(\.formaMotion) private var motion
  let id: String
  let name: String
  let animation: ExerciseMediaLibrary.Animation
  @State private var playing: Bool?

  private var isPlaying: Bool { playing ?? motion.allowsSpatialMotion }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Group {
        if isPlaying, let url = ExerciseMediaLibrary.url(id, "mp4", in: "animations") {
          LoopingVideo(url: url)
        } else {
          BundledImage(path: ("animations", id))
        }
      }
      .aspectRatio(animation.width / max(1, animation.height), contentMode: .fit)
      .background(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card))
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isImage)
      .accessibilityLabel("How to perform \(name): \(animation.description)")
      HStack {
        Text("Animated FORMA demonstration · \(animation.seconds.formatted()) s loop")
          .font(.footnote).foregroundStyle(FormaTheme.secondary)
        Spacer(minLength: 8)
        Button {
          playing = !isPlaying
        } label: {
          Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
            .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }
        .accessibilityLabel("\(isPlaying ? "Pause" : "Play") demonstration of \(name)")
      }
    }
    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
  }
}

/// A silent looping video with no controls, drawn by an `AVPlayerLayer`. It
/// plays while on screen and stops when it leaves.
private struct LoopingVideo: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> PlayerView {
    let view = PlayerView()
    view.start(url)
    return view
  }

  func updateUIView(_ view: PlayerView, context: Context) {}

  static func dismantleUIView(_ view: PlayerView, coordinator: ()) { view.stop() }

  final class PlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private var looper: AVPlayerLooper?
    private var player: AVQueuePlayer?

    func start(_ url: URL) {
      let queue = AVQueuePlayer()
      queue.isMuted = true
      // A looping drawing, not footage: the screen still sleeps as usual.
      queue.preventsDisplaySleepDuringVideoPlayback = false
      looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
      let layer = self.layer as? AVPlayerLayer
      layer?.player = queue
      layer?.videoGravity = .resizeAspect
      player = queue
      queue.play()
    }

    func stop() {
      player?.pause()
      looper = nil
      player = nil
    }
  }
}

/// A bundled HEIC from `Media/<folder>/<name>.heic`, decoded by
/// `MediaDecoder` and cached.
struct BundledImage: View {
  let path: (folder: String, name: String)
  var contentMode: ContentMode = .fit
  @State private var image: UIImage?

  var body: some View {
    ZStack {
      if let image {
        Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
      }
    }
    .task(id: "\(path.folder)/\(path.name)") {
      image = await BundledImageCache.load(path.folder, path.name)
    }
  }
}

@MainActor
enum BundledImageCache {
  private static let cache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 24
    return cache
  }()

  static func cached(_ folder: String, _ name: String) -> UIImage? {
    cache.object(forKey: "\(folder)/\(name)" as NSString)
  }

  static func load(_ folder: String, _ name: String) async -> UIImage? {
    if let image = cached(folder, name) { return image }
    guard let url = ExerciseMediaLibrary.url(name, "heic", in: folder) else { return nil }
    let image = await MediaDecoder.shared.decode(url)
    if let image { cache.setObject(image, forKey: "\(folder)/\(name)" as NSString) }
    return image
  }
}

/// One of the website's photos filling its frame, positioned like the web's
/// `background-position`: `focusY` 0 shows the top, 1 the bottom.
struct MediaPhoto: View {
  let photo: ExerciseMediaLibrary.Photo
  /// Where the photo's horizontal centre sits, 0 left to 1 right.
  var focusX: Double = 0.5
  @State private var image: UIImage?

  var body: some View {
    GeometryReader { proxy in
      if let image {
        let scale = max(
          proxy.size.width / max(1, image.size.width), proxy.size.height / max(1, image.size.height)
        )
        let width = image.size.width * scale
        let height = image.size.height * scale
        Image(uiImage: image).resizable()
          .frame(width: width, height: height)
          .offset(
            x: -(width - proxy.size.width) * focusX,
            y: -(height - proxy.size.height) * (photo.focusY ?? 0.5))
      }
    }
    .clipped()
    .background(FormaTheme.heroInk)
    .accessibilityHidden(true)
    .task(id: photo.file) {
      image = await BundledImageCache.load("photos", photo.file)
    }
  }
}

/// Where every picture, video and the display font in the app come from, and
/// under what terms. Each demo clip also carries its own credit in its guide.
struct MediaCreditsView: View {
  private var library: ExerciseMediaLibrary { .shared }
  @State private var fontLicence: String?

  var body: some View {
    List {
      Section("FORMA originals") {
        Text(
          "The exercise illustrations, the animated demonstrations and the training photos are FORMA's own, made with AI assistance for FORMA and shared with the website. They show invented people, not real athletes."
        )
        Text("Animations are recorded frame for frame from the website's drawings.")
          .font(.footnote).foregroundStyle(FormaTheme.secondary)
      }
      Section("Demo videos") {
        ForEach(library.sources.keys.sorted(), id: \.self) { key in
          if let source = library.sources[key] {
            let count = library.clips.values.filter { $0.source == key }.count
            VStack(alignment: .leading, spacing: 4) {
              Text(source.name).font(.headline)
              Text(countPhrase(count, "clip")).font(.footnote)
                .foregroundStyle(FormaTheme.secondary)
              if let url = URL(string: source.licenseUrl), url.scheme == "https" {
                Link(source.license, destination: url)
              } else {
                Text(source.license)
              }
              if !source.notice.isEmpty {
                Text(source.notice).font(.footnote).foregroundStyle(FormaTheme.secondary)
              }
            }
            .padding(.vertical, 4)
          }
        }
      }
      Section("Font") {
        VStack(alignment: .leading, spacing: 4) {
          Text("Barlow Condensed Bold").font(FormaDisplayFont.font(size: 22, relativeTo: .title3))
          Text("Copyright 2017 The Barlow Project Authors. SIL Open Font License 1.1.")
            .font(.footnote).foregroundStyle(FormaTheme.secondary)
        }
        DisclosureGroup("Read the licence") {
          Text(fontLicence ?? "").font(.caption.monospaced()).textSelection(.enabled)
        }
      }
    }
    .navigationTitle("Pictures, videos & font")
    .navigationBarTitleDisplayMode(.inline)
    .scrollContentBackground(.hidden)
    .background(FormaTheme.canvas)
    .task {
      guard fontLicence == nil,
        let url = Bundle.main.url(forResource: "barlowcondensed-OFL", withExtension: "txt")
      else { return }
      fontLicence = try? String(contentsOf: url, encoding: .utf8)
    }
  }
}
