import Foundation

// MARK: - Pivot Parsing (Mix / Playlist)

extension InnertubeClient {
    static func parsePivotPlaylist(
        json: [String: Any]
    )
        -> (title: String, videos: [Video])? {
        guard let first = extractFirstPivotSection(
            from: json
        ) else {
            return nil
        }
        let videos = extractPivotVideos(
            from: first
        )
        guard !videos.isEmpty else {
            return nil
        }
        let title = extractPivotTitle(from: first)
        return (title, videos)
    }
}

// MARK: - Private Helpers

private extension InnertubeClient {
    static func extractFirstPivotSection(
        from json: [String: Any]
    )
        -> [String: Any]? {
        guard let contents = json["contents"]
            as? [String: Any],
            let column = contents[
                "singleColumnWatchNextResults"
            ] as? [String: Any],
            let pivot = column["pivot"]
            as? [String: Any],
            let sectionList = pivot[
                "sectionListRenderer"
            ] as? [String: Any],
            let sections = sectionList["contents"]
            as? [[String: Any]],
            let first = sections.first
        else {
            return nil
        }
        return first
    }

    static func extractPivotVideos(
        from section: [String: Any]
    )
        -> [Video] {
        let shelf = section["shelfRenderer"]
            as? [String: Any]
        let content = shelf?["content"]
            as? [String: Any]
        let horizontal = content?[
            "horizontalListRenderer"
        ] as? [String: Any]
        let items = horizontal?["items"]
            as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard let tile = item["tileRenderer"]
                as? [String: Any]
            else {
                return nil
            }
            return parseTileRenderer(tile)
        }
    }

    static func extractPivotTitle(
        from section: [String: Any]
    )
        -> String {
        let shelf = section["shelfRenderer"]
            as? [String: Any]
        let header = shelf?["header"]
            as? [String: Any]
        let titleRenderer = header?[
            "playlistShelfHeaderRenderer"
        ] as? [String: Any]
        return simpleText(
            from: titleRenderer?["title"]
        ) ?? "Mix"
    }
}
