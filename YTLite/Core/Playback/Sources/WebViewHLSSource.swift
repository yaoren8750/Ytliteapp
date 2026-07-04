import AVFoundation
import Foundation

/// Source that plays the JS-context HLS manifest (kids / dubbed / rqh=1 content):
/// resolves it via `HLSStreamResolver` (URLSession + n-solve) and plays through
/// `HLSProxyLoader`. Owns quality selection by filtering the multivariant
/// manifest to the chosen resolution (the concrete 1080p fix).
final class WebViewHLSSource: VideoSource {
    let kind: VideoSourceKind = .webViewHLS
    let supportsQualitySelection = true
    private(set) var availableQualities: [VideoQuality] = []
    private(set) var currentQuality: VideoQuality?

    private let resolver: HLSStreamResolver
    private let proxyQueueLabel = "com.ytvlite.hlsproxy"
    private var manifestURL: URL?
    private var nSolver: (unsolved: String, solved: String)?
    private var activeLoader: HLSProxyLoader?

    init(resolver: HLSStreamResolver = .shared) {
        self.resolver = resolver
    }

    /// Parses the multivariant manifest into one quality per resolution height
    /// (plus an Auto entry), sorted high→low.
    static func parseQualities(from manifest: String) -> [VideoQuality] {
        var byHeight: [Int: VideoQuality] = [:]
        for line in manifest.components(separatedBy: "\n")
        where line.hasPrefix("#EXT-X-STREAM-INF") {
            let resText = HLSStreamResolver.firstMatch(
                in: line, pattern: "RESOLUTION=[0-9]+x([0-9]+)"
            )
            guard let height = resText.flatMap(Int.init) else {
                continue
            }
            let fpsText = HLSStreamResolver.firstMatch(
                in: line, pattern: "FRAME-RATE=([0-9]+)"
            )
            let fps = fpsText.flatMap(Int.init)
            let label = (fps ?? 0) > 30 ? "\(height)p\(fps ?? 0)" : "\(height)p"
            byHeight[height] = VideoQuality(
                id: "\(height)", label: label, height: height, fps: fps
            )
        }
        let heights = byHeight.values.sorted {
            ($0.height ?? 0) > ($1.height ?? 0)
        }
        let auto = VideoQuality(id: "auto", label: "Auto", height: nil, fps: nil)
        return [auto] + heights
    }

    func loadPlayback(
        videoId: String,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        resolver.resolve(videoId: videoId) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let resolved):
                self?.handleResolved(resolved, completion: completion)
            }
        }
    }

    func selectQuality(
        _ quality: VideoQuality,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        currentQuality = quality
        guard let prepared = buildPlayback(height: quality.height) else {
            completion(.failure(HLSStreamResolver.ResolverError.noManifest))
            return
        }
        completion(.success(prepared))
    }

    // MARK: - Private

    private func handleResolved(
        _ resolved: ResolvedHLS,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        manifestURL = resolved.manifestURL
        nSolver = resolved.nSolver
        resolver.fetchText(url: resolved.manifestURL) { [weak self] result in
            guard let self else {
                return
            }
            let manifest = (try? result.get()) ?? ""
            self.availableQualities = Self.parseQualities(from: manifest)
            self.currentQuality = self.availableQualities.first
            guard let prepared = self.buildPlayback(height: nil) else {
                completion(.failure(HLSStreamResolver.ResolverError.noManifest))
                return
            }
            completion(.success(prepared))
        }
    }

    private func buildPlayback(height: Int?) -> PreparedPlayback? {
        guard let manifestURL, let proxyURL = manifestURL.ytvProxyURL else {
            return nil
        }
        let loader = HLSProxyLoader(
            userAgent: resolver.desktopSafariUA, nSolver: nSolver
        )
        loader.selectedHeight = height
        activeLoader = loader
        let asset = AVURLAsset(url: proxyURL)
        asset.resourceLoader.setDelegate(
            loader, queue: DispatchQueue(label: proxyQueueLabel)
        )
        return PreparedPlayback(
            item: AVPlayerItem(asset: asset), resourceLoader: loader
        )
    }
}
