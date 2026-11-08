import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { m in SentTransferredFile(m.url) } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent("picked-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: dst)
            return PickedMovie(url: dst)
        }
    }
}

struct MainView: View {
    @EnvironmentObject var studio: Studio
    @State private var command = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var loadingPick = false
    @State private var showAbout = false
    @FocusState private var focused: Bool

    private let chips = ["منتج الريل بأسلوبي", "أضف لقطة ثلاثية الأبعاد عند ذكر الشاعر", "قص السكتات والإعادات", "أضف موسيقى خافتة", "اجعل التسميات بالذهبي"]

    var body: some View {
        GeometryReader { geo in
            let stageH = min(geo.size.height * 0.5, (geo.size.width - 40) * 16 / 9)
            ZStack {
                Background()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        header
                        StageView(height: stageH)
                        ProgressPanel()
                        if let v = studio.pickedVideo { shareClip(v) }
                        LogPanel()
                        if studio.done, studio.resultURL != nil {
                            Button { Haptic.tap(); studio.showFinish = true } label: { Label("افتحِ النتيجة: قصّ وحفظ ومشاركة", systemImage: "scissors") }
                                .buttonStyle(GoldButtonStyle())
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 20).padding(.top, 6)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) { commandBar }
        }
        .sheet(isPresented: $studio.showSuggestions) {
            SuggestionsSheet().environmentObject(studio).environment(\.layoutDirection, .rightToLeft)
        }
        .fullScreenCover(isPresented: $studio.showFinish) {
            if let u = studio.resultURL {
                FinishView(sourceURL: u, isDemo: studio.mode == .demo)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView().environmentObject(studio).environment(\.layoutDirection, .rightToLeft)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            loadingPick = true
            Task {
                if let m = try? await item.loadTransferable(type: PickedMovie.self) { studio.setPicked(m.url) }
                else { studio.addLog("تعذّر فتحُ المقطع المختار") }
                loadingPick = false
                pickerItem = nil
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("مونتاج كنان").font(AppFont.amiri(30)).foregroundStyle(Gold.gradient)
                Text("اكتبْ أمرَك، وشاهِدِ المونتاجَ حيًّا").font(AppFont.cairo(12, 500)).foregroundStyle(Gold.dim)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(studio.serverReachable == true ? Color.green : Gold.deep.opacity(0.7)).frame(width: 7, height: 7)
                Text(studio.serverReachable == true ? "متّصل" : "واتساب").font(AppFont.cairo(11, 600)).foregroundStyle(Gold.dim)
            }
            .padding(.horizontal, 10).padding(.vertical, 6).glassCard()
            Button { Haptic.tap(); showAbout = true } label: {
                Image(systemName: "info.circle").font(.system(size: 20, weight: .medium)).foregroundStyle(Gold.light)
                    .frame(width: 40, height: 40).glassCard()
            }
        }
    }

    private func shareClip(_ url: URL) -> some View {
        ShareLink(item: url) {
            HStack {
                Image(systemName: "paperplane.fill")
                Text("أرسِلِ المقطعَ إلى كنان (واتساب)").font(AppFont.cairo(14, 700))
                Spacer()
                Image(systemName: "film").foregroundStyle(Gold.dim)
            }
            .foregroundStyle(Gold.light).padding(14).glassCard()
        }
        .simultaneousGesture(TapGesture().onEnded { Haptic.tap() })
    }

    private var commandBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { Haptic.tap(); studio.startDemo() } label: {
                        Label("عرضٌ تجريبيّ", systemImage: "play.rectangle").font(AppFont.cairo(12, 700))
                            .foregroundStyle(Color.black).padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(Gold.gradientSoft))
                    }
                    ForEach(chips, id: \.self) { c in
                        Button { Haptic.soft(); command = c; focused = true } label: {
                            Text(c).font(AppFont.cairo(12, 600)).foregroundStyle(Gold.light)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(Gold.card)).overlay(Capsule().stroke(Gold.stroke, lineWidth: 0.8))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    ZStack {
                        if loadingPick { ProgressView().tint(Gold.light) }
                        else { Image(systemName: "photo.on.rectangle.angled").font(.system(size: 19, weight: .medium)).foregroundStyle(Gold.light) }
                    }
                    .frame(width: 46, height: 46).glassCard()
                }
                .simultaneousGesture(TapGesture().onEnded { Haptic.tap() })
                TextField("", text: $command, prompt: Text("اكتبْ أمرَك للمونتاج…").foregroundColor(Gold.dim), axis: .vertical)
                    .font(AppFont.cairo(15, 500)).foregroundStyle(Gold.text)
                    .lineLimit(1...3).focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 23).fill(Color.white.opacity(0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 23).stroke(Gold.stroke, lineWidth: 0.8))
                Button {
                    Haptic.tap(); focused = false
                    studio.send(command); command = ""
                } label: {
                    Image(systemName: "arrow.up").font(.system(size: 19, weight: .bold)).foregroundStyle(Color.black)
                        .frame(width: 46, height: 46).background(Circle().fill(Gold.gradient))
                        .shadow(color: Gold.light.opacity(0.45), radius: 10)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10).padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .background(Gold.bg.opacity(0.6))
    }
}

struct Background: View {
    var body: some View {
        ZStack {
            Gold.bg
            RadialGradient(colors: [Gold.deep.opacity(0.22), .clear], center: .top, startRadius: 10, endRadius: 420)
            RadialGradient(colors: [Gold.light.opacity(0.06), .clear], center: .bottomLeading, startRadius: 10, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

struct StageView: View {
    @EnvironmentObject var studio: Studio
    let height: CGFloat
    @State private var shimmer = false

    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            ZStack(alignment: .top) {
                if studio.rawURL != nil {
                    PlayerLayerView(player: studio.rawPlayer.player)
                        .overlay(Rectangle().fill(.ultraThinMaterial))
                        .overlay(Color.black.opacity(0.25))
                } else {
                    LinearGradient(colors: [Color.black, Gold.deep.opacity(0.18), Color.black], startPoint: shimmer ? .topLeading : .bottomTrailing, endPoint: shimmer ? .bottomTrailing : .topLeading)
                        .onAppear { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { shimmer = true } }
                }
                if studio.finalURL != nil {
                    PlayerLayerView(player: studio.finalPlayer.player)
                        .mask(alignment: .top) {
                            Rectangle().frame(maxWidth: .infinity).frame(height: h * studio.reveal)
                        }
                        .animation(.linear(duration: 0.15), value: studio.reveal)
                }
                if studio.reveal > 0 && studio.reveal < 1 {
                    ZStack {
                        Rectangle().fill(Gold.light).frame(height: 2.5)
                        Rectangle().fill(LinearGradient(colors: [Gold.light.opacity(0.0), Gold.light.opacity(0.35)], startPoint: .top, endPoint: .bottom)).frame(height: 40).offset(y: -20)
                    }
                    .shadow(color: Gold.light, radius: 12)
                    .offset(y: h * studio.reveal - 1.25)
                    .animation(.linear(duration: 0.15), value: studio.reveal)
                }
                if studio.mode == .idle && studio.rawURL == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles.rectangle.stack").font(.system(size: 42, weight: .light)).foregroundStyle(Gold.gradient)
                        Text("هنا يظهرُ الفيديو وهو يُمَنتَجُ أمامك").font(AppFont.cairo(15, 700)).foregroundStyle(Gold.text)
                        Text("اكتبْ أمرَك، أو اخترْ مقطعًا من صورك").font(AppFont.cairo(12, 500)).foregroundStyle(Gold.dim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VStack {
                    HStack {
                        Text(studio.badge).font(AppFont.cairo(12, 700))
                            .foregroundStyle(studio.mode == .live && !studio.done ? Color.black : Gold.light)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(studio.mode == .live && !studio.done ? AnyShapeStyle(Gold.gradient) : AnyShapeStyle(Color.black.opacity(0.55))))
                            .overlay(Capsule().stroke(Gold.stroke, lineWidth: 0.8))
                        Spacer()
                        if studio.stageIndex >= 0 {
                            Text(ar(Int(studio.progress.rounded())) + "٪").font(AppFont.cairo(13, 800)).foregroundStyle(Gold.light)
                                .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(Color.black.opacity(0.55)))
                        }
                    }
                    Spacer()
                    if studio.mode != .idle || studio.rawURL != nil {
                        CaptionBox()
                    }
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Gold.gradientSoft, lineWidth: 1))
            .shadow(color: Gold.deep.opacity(0.25), radius: 24, y: 8)
        }
        .frame(height: height)
    }
}

struct CaptionBox: View {
    @EnvironmentObject var studio: Studio
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: studio.done ? "checkmark.seal.fill" : "wand.and.stars").foregroundStyle(Gold.light).font(.system(size: 15))
            (Text(studio.done ? "تمّ. " : "الآن: ").font(AppFont.cairo(13, 800)).foregroundColor(Gold.light)
             + Text(studio.caption).font(AppFont.cairo(13, 500)).foregroundColor(Gold.text))
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Gold.stroke, lineWidth: 0.8))
        .animation(.easeInOut, value: studio.caption)
    }
}

struct ProgressPanel: View {
    @EnvironmentObject var studio: Studio
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    let ok = studio.stageIndex > i
                    let on = studio.stageIndex == i
                    VStack(spacing: 5) {
                        ZStack {
                            Circle().fill(ok ? AnyShapeStyle(Gold.gradient) : AnyShapeStyle(Color.white.opacity(0.06))).frame(width: 26, height: 26)
                            Circle().stroke(on ? Gold.light : Gold.stroke, lineWidth: on ? 1.6 : 0.8).frame(width: 26, height: 26)
                            if ok { Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color.black) }
                            else { Text(ar(i + 1)).font(AppFont.cairo(11, 700)).foregroundStyle(on ? Gold.light : Gold.dim) }
                        }
                        .shadow(color: on ? Gold.light.opacity(0.7) : .clear, radius: 6)
                        Text(STAGES[i].name).font(AppFont.cairo(10, on ? 800 : 600)).foregroundStyle(on || ok ? Gold.light : Gold.dim)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(Gold.gradient).frame(width: g.size.width * min(1, max(0, studio.progress / 100)))
                        .shadow(color: Gold.light.opacity(0.6), radius: 6)
                        .animation(.linear(duration: 0.15), value: studio.progress)
                }
            }
            .frame(height: 6)
            Text(statusLine).font(AppFont.cairo(12, 600)).foregroundStyle(Gold.dim)
        }
        .padding(14).glassCard()
    }
    private var statusLine: String {
        if studio.stageIndex < 0 { return studio.mode == .waiting ? "أُرسِلَ الأمر، بانتظار أن يبدأ كنان…" : "لم يبدأ المونتاجُ بعد" }
        if studio.done { return "اكتمل المونتاج" }
        return "المرحلة \(ar(studio.stageIndex + 1)) من \(ar(6)) · \(STAGES[studio.stageIndex].name)"
    }
}

struct LogPanel: View {
    @EnvironmentObject var studio: Studio
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("سِجِلُّ العمل", systemImage: "list.bullet.rectangle").font(AppFont.cairo(13, 800)).foregroundStyle(Gold.light)
            if studio.logLines.isEmpty {
                Text("سيظهرُ هنا كلُّ ما يجري، أوّلًا بأوّل.").font(AppFont.cairo(12, 500)).foregroundStyle(Gold.dim)
            }
            ForEach(studio.logLines.prefix(8)) { l in
                HStack(alignment: .top, spacing: 8) {
                    Text(ar(l.time.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))))
                        .font(AppFont.cairo(10, 600)).foregroundStyle(Gold.deep)
                    Text(l.text).font(AppFont.cairo(12, 500)).foregroundStyle(Gold.text.opacity(0.85))
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).glassCard()
        .animation(.easeOut(duration: 0.25), value: studio.logLines.count)
    }
}
