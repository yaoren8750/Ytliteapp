import Foundation

final class PlaybackQueue {
    static let shared = PlaybackQueue()
    private(set) var videos: [Video] = []
    private(set) var playlistTitle: String?

    var hasNext: Bool {
        videos.count > 1
    }

    var currentVideo: Video? {
        videos.first
    }

    private init() {}

    func setQueue(
        _ videos: [Video],
        title: String? = nil
    ) {
        self.videos = videos
        self.playlistTitle = title
    }

    func advanceToNext() -> Video? {
        guard hasNext else {
            return nil
        }
        videos.removeFirst()
        return videos.first
    }

    func seekTo(videoId: String) {
        guard let idx = videos.firstIndex(
            where: { $0.id == videoId }
        ) else {
            return
        }
        if idx > 0 {
            videos.removeFirst(idx)
        }
    }

    func clear() {
        videos = []
        playlistTitle = nil
    }
}
