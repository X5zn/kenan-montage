import SwiftUI
import AVFoundation

@MainActor
final class Studio: ObservableObject {
    enum Mode: Equatable { case idle, waiting, live, demo }

    @Published var mode: Mode = .idle
    @Published var progress: Double = 0          // 0…100
    @Published var stageIndex: Int = -1          // -1 idle, 0…5, 6 done
    @Published var caption = "اكتبْ أمرَك في الأسفل، وسترى المونتاجَ يجري أمامك خطوةً خطوة."
    @Published var logLines: [LogLine] = []
    @Published var options: [ShotOption] = []
    @Published var showSuggestions = false
    @Published var showFinish = false
    @Published var rawURL: URL?
    @Published var finalURL: URL?
    @Published var resultURL: URL?
    @Published var pickedVideo: URL?
    @Published var serverReachable: Bool?
    @Published var currentJobID: String?

    let rawPlayer = LoopingPlayer()
    let finalPlayer = LoopingPlayer()
    let statusURL = URL(string: "https://kenan-montage.sites.tab.bot/status.json")!

    private var demoTimer: Timer?
    private var pollTask: Task<Void, Never>?
    private var asked = false
    private var lastStage = -1
    private var seenRemoteLog = 0
    private var suggestionsKey = ""
    private var dismissedJobID: String? {
        get { UserDefaults.standard.string(forKey: "dismissedJobID") }
        set { UserDefaults.standard.set(newValue, forKey: "dismissedJobID") }
    }

    var done: Bool { stageIndex >= 6 }
    var reveal: Double { stageIndex >= 6 ? 1 : max(0, min(1, (progress - 20) / 80)) }
    var isRunning: Bool { (mode == .demo || mode == .live) && !done }

    var badge: String {
        switch mode {
        case .idle: return "جاهز"
        case .waiting: return "بانتظار كنان"
        case .live: return done ? "اكتمل" : "يُمَنتَجُ الآن"
        case .demo: return done ? "اكتمل العرض" : "عرضٌ تجريبيّ"
        }
    }

    // MARK: stage video
    func setStageVideos(raw: URL?, fin: URL?) {
        rawURL = raw; finalURL = fin
        rawPlayer.load(raw, muted: true)
        finalPlayer.load(fin, muted: true)
    }

    func addLog(_ t: String) { logLines.insert(LogLine(text: t), at: 0); if logLines.count > 60 { logLines.removeLast() } }

    private func applyStage(_ k: Int, text: String?) {
        if k != lastStage {
            if lastStage >= 0 && lastStage < 6 && k > lastStage { addLog("✓ اكتملتْ مرحلةُ \(STAGES[lastStage].name)") }
            lastStage = k
            if k < 6 { Haptic.soft() }
        }
        stageIndex = k
        if k < 6 { caption = (text?.isEmpty == false ? text! : STAGES[k].detail) }
    }

    // MARK: lifecycle
    func onLaunch() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        if let s = UserDefaults.standard.string(forKey: "screen") { screenshot(s); return }
        Task { if let s = await fetchStatus() { applyRemote(s) } }
    }
    func refreshOnForeground() {
        guard UserDefaults.standard.string(forKey: "screen") == nil else { return }
        if mode == .waiting || (mode == .live && !done) { startPolling() }
        else if mode == .idle { Task { if let s = await fetchStatus() { applyRemote(s) } } }
    }

    // MARK: picked clip
    func setPicked(_ url: URL) {
        pickedVideo = url
        addLog("✓ اخترتَ مقطعًا من صورك")
        if mode == .idle || mode == .waiting { setStageVideos(raw: url, fin: nil) }
        Haptic.success()
    }

    // MARK: real route — command to Kenan over WhatsApp, progress from status.json
    func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cmd = t.isEmpty ? "منتج الريل بأسلوبي" : t
        if mode == .demo { stopDemo() }
        WhatsApp.open(text: "أمر مونتاج: \(cmd)")
        mode = .waiting
        stageIndex = -1; progress = 0; lastStage = -1
        caption = "أُرسِلَ أمرُك إلى كنان عبر واتساب. حين يبدأ المونتاجُ ستراه هنا مباشرةً."
        addLog("أمرُك إلى كنان: «\(cmd)»")
        if pickedVideo != nil { addLog("أرسِلِ المقطعَ أيضًا من زرّ «أرسِلِ المقطعَ إلى كنان»") }
        startPolling()
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let s = await self.fetchStatus() { self.applyRemote(s) }
                if self.mode == .live && self.done { return }
                if self.mode != .waiting && self.mode != .live { return }
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }

    func fetchStatus() async -> JobStatus? {
        var comps = URLComponents(url: statusURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        var req = URLRequest(url: comps.url!)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 8
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let h = resp as? HTTPURLResponse, h.statusCode == 200 else { serverReachable = false; return nil }
            let s = try JSONDecoder().decode(JobStatus.self, from: data)
            serverReachable = true
            return s
        } catch {
            serverReachable = false
            return nil
        }
    }

    private func isFresh(_ iso: String?) -> Bool {
        guard let iso else { return true }
        let f1 = ISO8601DateFormatter()
        let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f1.date(from: iso) ?? f2.date(from: iso) else { return true }
        return Date().timeIntervalSince(d) < 3 * 3600
    }

    func applyRemote(_ s: JobStatus) {
        guard let id = s.job_id, !id.isEmpty else { return }
        let stage = max(0, min(6, s.stage ?? 0))
        switch mode {
        case .idle, .demo:
            guard stage < 6, isFresh(s.updated_at), id != dismissedJobID else { return }
        case .waiting:
            guard id != dismissedJobID || stage < 6 else { return }
        case .live:
            break
        }
        if mode == .demo { stopDemo() }
        if mode != .live || id != currentJobID {
            mode = .live; currentJobID = id
            lastStage = -1; seenRemoteLog = 0; suggestionsKey = ""
            addLog("بدأ كنانُ المونتاج")
        }
        // stage video: blurred raw underneath, Kenan's preview revealed on top
        let preview = s.preview_url.flatMap { URL(string: $0) }
        setStageVideos(raw: pickedVideo ?? preview, fin: preview)

        progress = s.percent ?? Double(stage) / 6 * 100
        applyStage(stage, text: s.stage_text_fusha)

        let lines = s.log ?? []
        if lines.count > seenRemoteLog { for l in lines[seenRemoteLog...] { addLog(l) }; seenRemoteLog = lines.count }

        let sugg = s.suggestions ?? []
        let key = sugg.map { ($0.title ?? "") + ($0.image_url ?? "") }.joined(separator: "|")
        if !sugg.isEmpty && key != suggestionsKey && stage < 6 {
            suggestionsKey = key
            options = sugg.enumerated().map { i, x in
                ShotOption(title: x.title ?? "لقطة \(ar(i + 1))", image: nil, imageURL: x.image_url.flatMap { URL(string: $0) })
            }
            showSuggestions = true
            Haptic.warn()
        }

        if stage >= 6 {
            caption = "تمّ. شاهِدِ النتيجة، أو قُصَّها بيدك، أو احفظْها في صورك."
            dismissedJobID = id
            if let f = s.final_url.flatMap({ URL(string: $0) }) {
                resultURL = f
                addLog("✓ اكتمل المونتاج — الفيديو النهائيّ جاهز")
                Haptic.success()
                showFinish = true
            }
            pollTask?.cancel()
        }
    }

    // MARK: suggestions
    func choose(_ index: Int) {
        guard options.indices.contains(index) else { return }
        let o = options[index]
        if mode == .demo {
            addLog("✓ اخترتَ: \(o.title)")
        } else {
            WhatsApp.open(text: "اخترتُ الاقتراح \(index + 1): \(o.title)")
            addLog("أرسلتَ اختيارك إلى كنان: \(o.title)")
        }
        showSuggestions = false
        Haptic.success()
    }
    func askForOthers() {
        if mode == .demo {
            if !options.isEmpty { options.append(options.removeFirst()) }
            addLog("طلبتَ اقتراحاتٍ أخرى")
        } else {
            WhatsApp.open(text: "اقترحْ لقطاتٍ غيرها")
            addLog("طلبتَ من كنان اقتراحاتٍ أخرى")
            showSuggestions = false
        }
        Haptic.tap()
    }

    // MARK: demo (clearly labelled «عرض», runs on bundled or chosen clip)
    func startDemo() {
        pollTask?.cancel()
        demoTimer?.invalidate()
        mode = .demo; progress = 0; stageIndex = 0; lastStage = -1; asked = false
        logLines = []
        addLog("عرضٌ تجريبيّ: مشهدٌ مُعَدٌّ مسبقًا، لا يُعدِّلُ الفيديو فعلًا")
        options = Bundled.shots
        setStageVideos(raw: pickedVideo ?? Bundled.raw, fin: pickedVideo ?? Bundled.final)
        rawPlayer.restart(); finalPlayer.restart()
        applyStage(0, text: nil)
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.demoTick() }
        }
    }
    func stopDemo() {
        demoTimer?.invalidate(); demoTimer = nil
        if mode == .demo { mode = .idle; stageIndex = -1; progress = 0 }
    }
    private func demoTick() {
        guard mode == .demo, !showSuggestions else { return }
        progress = min(100, progress + 0.5)
        applyStage(min(5, Int(progress / 100 * 6)), text: nil)
        if stageIndex == 3 && !asked {
            asked = true; showSuggestions = true
            addLog("⏸ بانتظار اختيارك للّقطة"); Haptic.warn()
        }
        if progress >= 100 { finishDemo() }
    }
    private func finishDemo() {
        demoTimer?.invalidate(); demoTimer = nil
        stageIndex = 6
        caption = "انتهى العرض. جرِّبِ القصَّ اليدويّ والحفظ على المقطع."
        addLog("✓ انتهى العرضُ التجريبيّ")
        resultURL = pickedVideo ?? Bundled.final
        Haptic.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.showFinish = true }
    }

    // MARK: CI screenshots (-screen main|suggest|finish)
    private func screenshot(_ name: String) {
        options = Bundled.shots
        setStageVideos(raw: Bundled.raw, fin: Bundled.final)
        mode = .demo
        logLines = []
        addLog("عرضٌ تجريبيّ: مشهدٌ مُعَدٌّ مسبقًا، لا يُعدِّلُ الفيديو فعلًا")
        addLog("✓ اكتملتْ مرحلةُ التفريغ"); addLog("✓ اكتملتْ مرحلةُ القصّ")
        switch name {
        case "suggest":
            progress = 55; lastStage = 3; stageIndex = 3; caption = STAGES[3].detail
            addLog("✓ اكتملتْ مرحلةُ التسميات"); addLog("⏸ بانتظار اختيارك للّقطة")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.showSuggestions = true }
        case "finish":
            progress = 100; stageIndex = 6; resultURL = Bundled.final
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.showFinish = true }
        default:
            progress = 46; lastStage = 2; stageIndex = 2; caption = STAGES[2].detail
        }
    }
}
