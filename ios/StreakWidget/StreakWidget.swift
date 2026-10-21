// terrimap ホーム画面ウィジェット（iOS・WidgetKit）。
// Flutter 側（lib/widget_sync.dart）が App Group の UserDefaults に書いた3つの文字列（streak / landmark / status）を出すだけ。
// 導入手順は core の docs/ios_widget_setup_v0_1.md。Xcode の「Widget Extension」ターゲットを作り、このファイルで置き換える。
import SwiftUI
import WidgetKit

// Flutter 側の HomeWidgetSync.iosAppGroup と同じ値にする。Runner とこの拡張の両方で、同じ App Group を有効にする。
private let appGroup = "group.dev.terrimap.terrimapUs"

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: String
    let landmark: String
    let status: String
    let skin: Int
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: "3", landmark: "Terrimap", status: "", skin: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // アプリが書き出すたびに再読み込みされる（Flutter 側の updateWidget）。念のため1時間ごとにも読み直す。
        completion(Timeline(entries: [load()], policy: .after(Date().addingTimeInterval(60 * 60))))
    }

    private func load() -> StreakEntry {
        let d = UserDefaults(suiteName: appGroup)
        return StreakEntry(
            date: Date(),
            streak: d?.string(forKey: "streak") ?? "",
            landmark: d?.string(forKey: "landmark") ?? "",
            status: d?.string(forKey: "status") ?? "",
            skin: d?.integer(forKey: "skin") ?? 0
        )
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🔥 \(entry.streak)")
                .font(.system(size: 28, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !entry.landmark.isEmpty {
                Text("📍 \(entry.landmark)")
                    .font(.system(size: 13))
                    .lineLimit(2)
            }
            if !entry.status.isEmpty {
                Text(entry.status)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .foregroundColor(entry.skin > 0 ? .white : nil)
        .widgetBackground(skinColor(entry.skin))
    }
}

/// 配色番号(Flutter 側 `widgetSkinIndex`)。0 は標準(システム背景)、1〜5 は衣装ごとの配色。
func skinColor(_ i: Int) -> Color {
    let hex: [UInt32] = [0, 0x2E7D32, 0x6A1B9A, 0xE65100, 0xAD1457, 0x37474F]
    guard i > 0, i < hex.count else { return Color(UIColor.systemBackground) }
    let h = hex[i]
    return Color(red: Double((h >> 16) & 0xFF) / 255, green: Double((h >> 8) & 0xFF) / 255, blue: Double(h & 0xFF) / 255)
}

extension View {
    /// iOS 17 以降は containerBackground、それより前は background。
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}

// Flutter 側の HomeWidgetSync.iosWidgetName（updateWidget の iOSName）と同じ名前にする。
@main
struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Terrimap")
        .description("Streak and today's landmark")
        .supportedFamilies([.systemSmall])
    }
}
