import Foundation

// MARK: - Playlist rewriting

extension HLSProxyLoader {
    /// Diagnostic: logs the variant resolutions of a multivariant manifest, or
    /// the itag AVPlayer is fetching for a child (reveals the chosen quality).
    static func logPlaylist(data: Data, url: URL) {
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }
        if text.contains("#EXT-X-STREAM-INF") {
            let resolutions = text.components(separatedBy: "\n")
                .compactMap { line -> String? in
                    guard line.hasPrefix("#EXT-X-STREAM-INF") else {
                        return nil
                    }
                    return HLSStreamResolver.firstMatch(
                        in: line, pattern: "RESOLUTION=([0-9x]+)"
                    )
                }
            AppLog.player(
                "hlsProxy: multivariant, resolutions="
                    + resolutions.joined(separator: ",")
            )
        } else {
            let itag = HLSStreamResolver.firstMatch(
                in: url.absoluteString, pattern: "/itag/([0-9]+)/"
            ) ?? "?"
            AppLog.player("hlsProxy: child playlist itag=\(itag)")
        }
    }

    func rewrittenPlaylistData(_ data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8) else {
            return data
        }
        return rewritePlaylist(text).data(using: .utf8) ?? data
    }

    /// 1. Replace the unsolved n-value with the solved one across the playlist
    ///    (a single session-wide value, so a global replace is safe).
    /// 2. For master manifests, route child variant/rendition playlists back
    ///    through the proxy so they get the same UA + n-rewrite.
    private func rewritePlaylist(_ m3u8: String) -> String {
        var text = m3u8
        if let solver = nSolver, solver.unsolved != solver.solved {
            text = text.replacingOccurrences(
                of: "/n/\(solver.unsolved)/",
                with: "/n/\(solver.solved)/"
            )
        }
        let isMultiVariant = text.contains("#EXT-X-STREAM-INF")
            || text.contains("#EXT-X-MEDIA:")
        guard isMultiVariant else {
            return text
        }
        return proxyingChildURIs(in: text)
    }

    private func proxyingChildURIs(in text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var out: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("#EXT-X-STREAM-INF") {
                let uri = index + 1 < lines.count ? lines[index + 1] : ""
                if keepVariant(streamInf: line) {
                    out.append(line)
                    out.append(proxied(uri))
                }
                index += 2
                continue
            }
            out.append(
                line.hasPrefix("#EXT-X-MEDIA:") ? proxiedMedia(line) : line
            )
            index += 1
        }
        return out.joined(separator: "\n")
    }

    /// Keeps every variant during ABR; when a height is pinned, keeps only the
    /// variants at that resolution (forcing e.g. 1080p over AVPlayer's ABR).
    private func keepVariant(streamInf: String) -> Bool {
        guard let height = selectedHeight else {
            return true
        }
        let match = HLSStreamResolver.firstMatch(
            in: streamInf, pattern: "RESOLUTION=[0-9]+x([0-9]+)"
        )
        return match.flatMap(Int.init) == height
    }

    private func proxied(_ uri: String) -> String {
        let trimmed = uri.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("https://") else {
            return uri
        }
        return trimmed.replacingOccurrences(
            of: "https://", with: "\(HLSProxy.scheme)://"
        )
    }

    private func proxiedMedia(_ line: String) -> String {
        line.replacingOccurrences(
            of: "URI=\"https://", with: "URI=\"\(HLSProxy.scheme)://"
        )
    }
}
