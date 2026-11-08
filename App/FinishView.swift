import SwiftUI
import AVKit
import Photos

struct FinishView: View {
    let sourceURL: URL
    let isDemo: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var localURL: URL?
    @State private var loadError: String?
    @State private var player = AVPlayer()
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var observer: Any?
    @State private var shareURL: URL?
    @State private var exportedRange: ClosedRange<Double>?
    @State private var busy = false
    @State private var note: String?

    private var dirty: Bool {
        guard duration > 0 else { return false }
        let full = start < 0.05 && end > duration - 0.05
        if full { return false }
        return exportedRange != start...end
    }

    var body: some View {
        ZStack {
            Background()
            VStack(spacing: 14) {
                HStack {
                    Button { Haptic.tap(); dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Gold.light).frame(width: 40, height: 40).glassCard()
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("الفيديو النهائيّ").font(AppFont.amiri(24)).foregroundStyle(Gold.gradient)
                        if isDemo { Text("عرضٌ تجريبيّ").font(AppFont.cairo(11, 700)).foregroundStyle(Gold.dim) }
                    }
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                if let localURL {
                    VideoPlayer(player: player)
                        .frame(maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Gold.gradientSoft, lineWidth: 1))
                    trimPanel
                    actions(localURL)
                } else if let loadError {
                    Spacer()
                    Text(loadError).font(AppFont.cairo(14, 600)).foregroundStyle(Gold.text).multilineTextAlignment(.center)
                    Spacer()
                } else {
                    Spacer()
                    ProgressView().tint(Gold.light)
                    Text("أُنزِّلُ الفيديو…").font(AppFont.cairo(14, 600)).foregroundStyle(Gold.dim)
                    Spacer()
                }
                if let note { Text(note).font(AppFont.cairo(13, 600)).foregroundStyle(Gold.light).transition(.opacity) }
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
        }
        .task { await prepare() }
        .onDisappear {
            player.pause()
            if let o = observer { player.removeTimeObserver(o); observer = nil }
        }
    }

    private var trimPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("القصُّ اليدويّ", systemImage: "scissors").font(AppFont.cairo(13, 800)).foregroundStyle(Gold.light)
                Spacer()
                Text("المدّة \(arTime(max(0, end - start)))").font(AppFont.cairo(12, 600)).foregroundStyle(Gold.dim)
            }
            HStack {
                Text("البداية").font(AppFont.cairo(12, 600)).foregroundStyle(Gold.dim).frame(width: 52, alignment: .leading)
                Slider(value: $start, in: 0...max(duration, 0.1), onEditingChanged: { e in if e { Haptic.soft() } else { seekStart() } })
                Text(arTime(start)).font(AppFont.cairo(12, 700)).foregroundStyle(Gold.text).frame(width: 40)
            }
            HStack {
                Text("النهاية").font(AppFont.cairo(12, 600)).foregroundStyle(Gold.dim).frame(width: 52, alignment: .leading)
                Slider(value: $end, in: 0...max(duration, 0.1), onEditingChanged: { e in if e { Haptic.soft() } else { seekStart() } })
                Text(arTime(end)).font(AppFont.cairo(12, 700)).foregroundStyle(Gold.text).frame(width: 40)
            }
        }
        .padding(14).glassCard()
        .onChange(of: start) { _, v in if v > end - 0.5 { start = max(0, end - 0.5) } }
        .onChange(of: end) { _, v in if v < start + 0.5 { end = min(duration, start + 0.5) } }
    }

    private func actions(_ url: URL) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { Task { await save() } } label: {
                    HStack {
                        if busy { ProgressView().tint(.black) } else { Image(systemName: "square.and.arrow.down") }
                        Text("احفظْ في الصور")
                    }
                }
                .buttonStyle(GoldButtonStyle()).disabled(busy)
                if dirty {
                    Button { Task { _ = await exportIfNeeded() } } label: { Label("طبِّقِ القصّ", systemImage: "scissors") }
                        .buttonStyle(GoldButtonStyle(filled: false)).disabled(busy)
                } else {
                    ShareLink(item: shareURL ?? url) { Label("شارِك", systemImage: "square.and.arrow.up") }
                        .buttonStyle(GoldButtonStyle(filled: false))
                        .simultaneousGesture(TapGesture().onEnded { Haptic.tap() })
                }
            }
        }
    }

    // MARK: work
    private func prepare() async {
        var url = sourceURL
        if !sourceURL.isFileURL {
            do {
                let (tmp, resp) = try await URLSession.shared.download(from: sourceURL)
                guard (resp as? HTTPURLResponse)?.statusCode ?? 200 < 400 else { throw URLError(.badServerResponse) }
                let dst = FileManager.default.temporaryDirectory.appendingPathComponent("kenan-final-\(UUID().uuidString).mp4")
                try FileManager.default.moveItem(at: tmp, to: dst)
                url = dst
            } catch {
                loadError = "تعذّر تنزيلُ الفيديو النهائيّ. تأكّدْ من الاتصال وحاوِلْ مجدّدًا."
                return
            }
        }
        let asset = AVURLAsset(url: url)
        let d = (try? await asset.load(.duration).seconds) ?? 0
        duration = d.isFinite ? d : 0
        start = 0; end = duration
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        localURL = url; shareURL = url
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { t in
            if end > 0 && t.seconds >= end { player.seek(to: CMTime(seconds: start, preferredTimescale: 600)) }
        }
        player.play()
    }

    private func seekStart() {
        player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }

    private func exportIfNeeded() async -> URL? {
        guard let localURL else { return nil }
        guard dirty else { return shareURL ?? localURL }
        busy = true; defer { busy = false }
        let asset = AVURLAsset(url: localURL)
        guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { flash("تعذّر القصّ"); return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("مونتاج-كنان-\(Int(Date().timeIntervalSince1970)).mp4")
        s.outputURL = out
        s.outputFileType = .mp4
        s.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: end, preferredTimescale: 600))
        await s.export()
        guard s.status == .completed else { flash("تعذّر القصّ: \(s.error?.localizedDescription ?? "")"); return nil }
        shareURL = out; exportedRange = start...end
        Haptic.success(); flash("✓ قُصَّ الفيديو من \(arTime(start)) إلى \(arTime(end))")
        return out
    }

    private func save() async {
        Haptic.tap()
        guard let url = await exportIfNeeded() else { return }
        let st = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard st == .authorized || st == .limited else { flash("اسمحْ للتطبيق بالحفظ في الصور من الإعدادات"); Haptic.warn(); return }
        busy = true; defer { busy = false }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }
            Haptic.success(); flash("✓ حُفِظَ الفيديو في صورك")
        } catch {
            Haptic.warn(); flash("تعذّر الحفظ في الصور")
        }
    }

    private func flash(_ t: String) {
        withAnimation { note = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { if note == t { note = nil } } }
    }
}
