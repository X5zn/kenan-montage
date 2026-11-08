import Foundation
import UIKit

struct StageInfo { let name: String; let detail: String }

let STAGES: [StageInfo] = [
    StageInfo(name: "التفريغ", detail: "أُفرِّغُ كلامَك نصًّا، كلمةً كلمة، لأعرفَ موضعَ كلِّ لفظة."),
    StageInfo(name: "القصّ", detail: "أحذفُ السكتاتِ الطويلةَ والإعاداتِ والأخطاء، فلا يبقى إلا الكلامُ المتصل."),
    StageInfo(name: "التسميات", detail: "أُضيفُ التسمياتِ النصّيّة بأسلوبك: كلُّ كلمةٍ تظهرُ مع صوتك، والمفتاحيّةُ بالأصفر."),
    StageInfo(name: "اللقطات", detail: "أختارُ لقطاتٍ تُناسبُ المعنى، وأعرضُ عليك الاقتراحات."),
    StageInfo(name: "الصوت", detail: "أضبطُ صوتَك، وأضعُ موسيقى خافتةً ومؤثراتٍ عند الانتقالات."),
    StageInfo(name: "التصدير", detail: "أُصدِّرُ الفيديو بجودةٍ عالية، جاهزًا للنشر.")
]

/// The job status Kenan publishes at https://kenan-montage.sites.tab.bot/status.json
/// Every field is optional so a partial file still decodes.
struct RemoteSuggestion: Codable, Hashable { var title: String?; var image_url: String? }
struct JobStatus: Codable, Equatable {
    var job_id: String?
    var stage: Int?            // 0…5 working, 6 = done
    var stage_text_fusha: String?
    var percent: Double?
    var log: [String]?
    var suggestions: [RemoteSuggestion]?
    var preview_url: String?
    var final_url: String?
    var updated_at: String?
}

struct ShotOption: Identifiable {
    let id = UUID()
    let title: String
    let image: UIImage?
    let imageURL: URL?
}

struct LogLine: Identifiable { let id = UUID(); let text: String; let time = Date() }

enum Bundled {
    static let raw = Bundle.main.url(forResource: "raw", withExtension: "mp4")!
    static let final = Bundle.main.url(forResource: "final", withExtension: "mp4")!
    static func image(_ name: String) -> UIImage? {
        guard let p = Bundle.main.path(forResource: name, ofType: "jpg") else { return nil }
        return UIImage(contentsOfFile: p)
    }
    static var shots: [ShotOption] {
        [("s1", "قصرٌ عبّاسيّ عند الغروب"), ("s2", "بيداءُ تحت النجوم"), ("s3", "سيفٌ وقلمٌ على مخطوطة"), ("s4", "مجلسُ شعرٍ قديم")]
            .map { ShotOption(title: $0.1, image: image($0.0), imageURL: nil) }
    }
}

enum WhatsApp {
    static let number = "12512765320"   // كنان
    static func open(text: String) {
        var c = URLComponents(string: "https://wa.me/\(number)")!
        c.queryItems = [URLQueryItem(name: "text", value: text)]
        if let u = c.url { UIApplication.shared.open(u) }
    }
}
