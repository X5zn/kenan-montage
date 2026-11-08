import SwiftUI

struct AboutView: View {
    @EnvironmentObject var studio: Studio
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Background()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("عن التطبيق").font(AppFont.amiri(30)).foregroundStyle(Gold.gradient)
                        Spacer()
                        Button { Haptic.tap(); dismiss() } label: { Image(systemName: "xmark").foregroundStyle(Gold.light).frame(width: 36, height: 36).glassCard() }
                    }
                    section("كيف يعمل", [
                        "تكتبُ أمرَك هنا وتضغطُ زرَّ الإرسال، فيفتحُ التطبيقُ واتساب على محادثة كنان والأمرُ مكتوبٌ جاهزًا، فتُرسِلُه.",
                        "إن اخترتَ مقطعًا من صورك، فأرسِلْه إلى كنان من زرّ «أرسِلِ المقطعَ إلى كنان».",
                        "كنانُ يُمَنتِجُ، وحين ينشرُ حالةَ المهمّة على رابطه يعرضُ التطبيقُ المراحلَ والنسبةَ والسجلَّ والمعاينةَ والاقتراحاتِ مباشرةً، ويتحدّثُ كلَّ عشر ثوانٍ.",
                        "حين يكتملُ الفيديو تقصُّه بيدك، وتحفظُه في صورك، أو تشاركُه."
                    ])
                    section("بصراحة، في هذا الإصدار", [
                        "لا يحتوي التطبيقُ على خادمٍ يُمَنتِجُ بنفسه، ولا يتحدّثُ مع كنان من داخله؛ الأوامرُ تصلُ عبر واتساب.",
                        "التقدّمُ الحيُّ يظهرُ فقط حين ينشرُ كنانُ حالةَ المهمّة على رابطه، وإلّا بقيتْ الشاشةُ بانتظاره.",
                        "«العرضُ التجريبيّ» مشهدٌ مُعَدٌّ مسبقًا على مقطعٍ محفوظ أو على مقطعك، ولا يُعدِّلُ الفيديو فعلًا.",
                        "القصُّ اليدويُّ والحفظُ في الصور والمشاركةُ واختيارُ المقطع من الصور تعملُ فعلًا على جهازك.",
                        "التطبيقُ غيرُ موقَّعٍ من متجر آبل، فيحتاجُ إلى إعادة التثبيت كلَّ سبعة أيام عبر Sideloadly."
                    ])
                    HStack {
                        Text("حالةُ الرابط:").font(AppFont.cairo(13, 700)).foregroundStyle(Gold.light)
                        Text(studio.serverReachable == true ? "منشورٌ ومتّصل" : "لم تُنشَرْ حالةُ مهمّةٍ بعد")
                            .font(AppFont.cairo(13, 500)).foregroundStyle(Gold.text)
                    }
                    Text("مونتاج كنان · الإصدار ١٫٠").font(AppFont.cairo(12, 500)).foregroundStyle(Gold.dim)
                }
                .padding(22)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func section(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(AppFont.cairo(16, 800)).foregroundStyle(Gold.light)
            ForEach(items, id: \.self) { t in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Gold.gradient).frame(width: 6, height: 6).padding(.top, 9)
                    Text(t).font(AppFont.cairo(14, 500)).foregroundStyle(Gold.text).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).glassCard()
    }
}
