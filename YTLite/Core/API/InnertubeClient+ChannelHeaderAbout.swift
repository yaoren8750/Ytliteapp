import Foundation

// MARK: - TV channelHeaderRenderer extras
//
// The TVHTML5 channel header (2026-07 shape) carries the subscriber
// count in its subtitle line and hides description + channel stats
// inside the About engagement panel of `selectableDescription`.

extension InnertubeClient {
    static func applyChannelHeaderExtras(
        _ ch: [String: Any],
        into fields: inout ChannelFields
    ) {
        if fields.subscriberCountText == nil {
            fields.subscriberCountText = subtitleSubCount(ch)
        }
        guard let about = headerAboutViewModel(ch) else {
            return
        }
        if fields.desc == nil {
            fields.desc = (about["description"] as? String)
                .flatMap { $0.isEmpty ? nil : $0 }
        }
        let labels = (about["infoRows"] as? [[String: Any]] ?? [])
            .compactMap { $0["label"] as? String }
        if fields.subscriberCountText == nil {
            fields.subscriberCountText = labels.first {
                $0.contains("subscriber")
            }
        }
        fields.videoCountText = labels.first { $0.contains("video") }
    }
}

private extension InnertubeClient {
    static func subtitleSubCount(
        _ ch: [String: Any]
    ) -> String? {
        let items = ch.digArray(
            "subtitle", RendererKey.line, JSONKey.items
        ) ?? []
        return items
            .compactMap { item in
                let rdr = item[RendererKey.lineItem] as? [String: Any]
                return simpleText(from: rdr?[JSONKey.text])
            }
            .first { $0.contains("subscriber") }
    }

    static func headerAboutViewModel(
        _ ch: [String: Any]
    ) -> [String: Any]? {
        ch.digDict(
            "selectableDescription",
            "selectableTextRenderer",
            "onSelectCommand",
            "showEngagementPanelEndpoint",
            "engagementPanel",
            "engagementPanelSectionListRenderer",
            JSONKey.content,
            "aboutChannelViewModel"
        )
    }
}
