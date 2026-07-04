import UIKit

// MARK: - Quality picker
//
// Routes to the active `VideoSource`'s quality menu when it owns quality
// selection; otherwise falls back to the legacy DASH/generated-HLS picker
// (android_vr path, still driven by `DirectPlaybackInfo.allDashVideoFormats`
// until AndroidVRSource lands).

extension WatchViewController {
    func showQualityPicker() {
        if let source = playbackFacade.activeVideoSource,
           source.supportsQualitySelection {
            showSourceQualityPicker(source: source)
            return
        }
        showDashQualityPicker()
    }

    private func showDashQualityPicker() {
        guard let info = playbackFacade.activePlaybackInfo,
              let audioFormat = info.dashAudioFormat else {
            return
        }
        let formats = info.allDashVideoFormats
        guard !formats.isEmpty else {
            return
        }
        let alert = UIAlertController(
            title: "Quality", message: nil, preferredStyle: .actionSheet
        )
        for format in formats {
            addQualityAction(to: alert, format: format, audioFormat: audioFormat)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configurePopover(for: alert, sourceView: videoPlayerView)
        present(alert, animated: true)
    }

    private func addQualityAction(
        to alert: UIAlertController,
        format: DashFormatInfo,
        audioFormat: DashFormatInfo
    ) {
        let label = qualityLabel(for: format)
        let active = playbackFacade.activeVideoFormat
        let title = format.itag == active?.itag ? "✓ \(label)" : label
        alert.addAction(
            UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.switchQuality(
                    to: format, audioFormat: audioFormat, label: label
                )
            }
        )
    }

    private func switchQuality(
        to format: DashFormatInfo,
        audioFormat: DashFormatInfo,
        label: String
    ) {
        let active = playbackFacade.activeVideoFormat
        guard format.itag != active?.itag else {
            return
        }
        let client = playbackFacade.activePlaybackClient
        let videoURL = prepareDirectPlaybackURL(
            baseURL: format.url, client: client, poToken: nil
        )
        let audioURL = prepareDirectPlaybackURL(
            baseURL: audioFormat.url, client: client, poToken: nil
        )
        playerStatusLabel.text = "Loading \(label)..."
        playerStatusLabel.isHidden = false
        buildHLSAndPlay(
            videoURL: videoURL,
            audioURL: audioURL,
            videoFormat: format,
            audioFormat: audioFormat,
            headers: playbackFacade.activePlaybackHeaders,
            quality: label
        )
    }

    private func qualityLabel(for format: DashFormatInfo) -> String {
        guard let height = format.height else {
            return "itag \(format.itag)"
        }
        if let fps = format.fps, fps > 30 {
            return "\(height)p\(fps)"
        }
        return "\(height)p"
    }
}
