import SwiftUI
import AVFoundation
import UIKit

final class LoopingPlayer {
    let player = AVPlayer()
    private var endObserver: NSObjectProtocol?
    private(set) var url: URL?

    func load(_ newURL: URL?, muted: Bool = true) {
        player.isMuted = muted
        guard newURL != url else { if newURL != nil { player.play() }; return }
        url = newURL
        if let o = endObserver { NotificationCenter.default.removeObserver(o); endObserver = nil }
        guard let newURL else { player.replaceCurrentItem(with: nil); return }
        let item = AVPlayerItem(url: newURL)
        player.replaceCurrentItem(with: item)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        player.play()
    }
    func restart() { player.seek(to: .zero); player.play() }
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        v.backgroundColor = .black
        return v
    }
    func updateUIView(_ v: PlayerUIView, context: Context) {
        if v.playerLayer.player !== player { v.playerLayer.player = player }
    }
}
