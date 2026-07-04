import AVFoundation
import UIKit

// MARK: - Source-prepared playback

extension WatchViewController {
    /// Attaches an `AVPlayerItem` built by a `VideoSource`, retaining its
    /// resource loader (e.g. the HLS proxy) for the item's lifetime and
    /// publishing any caption tracks the source resolved.
    func attachPrepared(_ prepared: PreparedPlayback) {
        activeResourceLoader = prepared.resourceLoader
        if !prepared.captions.isEmpty {
            setCaptionTracks(prepared.captions)
        }
        attachPlayer(item: prepared.item)
    }

    /// Source-agnostic quality menu: renders `source.availableQualities` and
    /// applies the pick via `source.selectQuality`. No source-specific code.
    func showSourceQualityPicker(source: VideoSource) {
        let alert = UIAlertController(
            title: "Quality", message: nil, preferredStyle: .actionSheet
        )
        for quality in source.availableQualities {
            let isCurrent = quality == source.currentQuality
            let title = isCurrent ? "✓ \(quality.label)" : quality.label
            alert.addAction(
                UIAlertAction(title: title, style: .default) { [weak self] _ in
                    self?.selectSourceQuality(quality, source: source)
                }
            )
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configurePopover(for: alert, sourceView: videoPlayerView)
        present(alert, animated: true)
    }

    private func selectSourceQuality(
        _ quality: VideoQuality,
        source: VideoSource
    ) {
        playerStatusLabel.text = "Loading \(quality.label)..."
        playerStatusLabel.isHidden = false
        source.selectQuality(quality) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let prepared):
                    self?.attachPrepared(prepared)
                case .failure:
                    self?.showPlaybackError("Quality switch failed.")
                }
            }
        }
    }
}
