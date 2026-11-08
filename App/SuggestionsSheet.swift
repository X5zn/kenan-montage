import SwiftUI

struct SuggestionsSheet: View {
    @EnvironmentObject var studio: Studio
    @State private var sel = 0
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Background()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("اختَرِ اللقطة").font(AppFont.amiri(28)).foregroundStyle(Gold.gradient)
                        Text(studio.mode == .demo ? "عرضٌ تجريبيّ — لقطاتٌ محفوظة في التطبيق" : "اقتراحاتُ كنان لهذا الموضع من الفيديو")
                            .font(AppFont.cairo(13, 500)).foregroundStyle(Gold.dim)
                    }
                    .padding(.top, 22)
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(Array(studio.options.enumerated()), id: \.element.id) { i, o in
                            card(i, o)
                                .onTapGesture { Haptic.soft(); withAnimation(.spring(duration: 0.3)) { sel = i } }
                        }
                    }
                    HStack(spacing: 10) {
                        Button("اعتمد") { studio.choose(sel) }.buttonStyle(GoldButtonStyle())
                        Button("اقترح غيرها") { sel = 0; studio.askForOthers() }.buttonStyle(GoldButtonStyle(filled: false))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(studio.mode == .demo)
    }

    private func card(_ i: Int, _ o: ShotOption) -> some View {
        let on = sel == i
        return ZStack(alignment: .bottom) {
            Group {
                if let img = o.image {
                    Image(uiImage: img).resizable().scaledToFill()
                } else if let u = o.imageURL {
                    AsyncImage(url: u) { ph in
                        if let im = ph.image { im.resizable().scaledToFill() } else { ProgressView().tint(Gold.light) }
                    }
                } else { Gold.card }
            }
            .frame(maxWidth: .infinity).frame(height: 210).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack {
                HStack {
                    Text(ar(i + 1)).font(AppFont.cairo(13, 800)).foregroundStyle(on ? Color.black : Gold.light)
                        .frame(width: 28, height: 28).background(Circle().fill(on ? AnyShapeStyle(Gold.gradient) : AnyShapeStyle(Color.black.opacity(0.6))))
                    Spacer()
                    if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(Gold.light).font(.system(size: 20)) }
                }
                Spacer()
                Text(o.title).font(AppFont.cairo(13, 700)).foregroundStyle(Gold.text).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(on ? Gold.light : Gold.stroke, lineWidth: on ? 2 : 0.8))
        .shadow(color: on ? Gold.light.opacity(0.45) : .clear, radius: 12)
        .scaleEffect(on ? 1.0 : 0.97)
    }
}
