import Foundation

struct PackingItem: Identifiable {
    let id: String
    let name: String
    let category: String

    init(_ name: String, category: String) {
        self.id = name
        self.name = name
        self.category = category
    }
}

/// Rule-based packing list — no AI. The baseline items and categories are
/// drawn from JTB's published travel checklist (国内/海外 editions), with
/// climate + trip-type + duration layered on top as additions. Items are
/// de-duplicated by name at the end since the layers can legitimately
/// overlap (e.g. a hot-climate addition that's already in the baseline).
enum PackingListGenerator {
    static func generate(climate: ClimateSummary, tripType: TripType, days: Int, isInternational: Bool) -> [PackingItem] {
        var items = baseItems(isInternational: isInternational, days: days)
        items += climateItems(for: climate.category)
        items += tripTypeItems(for: tripType)
        return dedupedByName(items)
    }

    private static func dedupedByName(_ items: [PackingItem]) -> [PackingItem] {
        var seenNames = Set<String>()
        return items.filter { seenNames.insert($0.name).inserted }
    }

    private static func baseItems(isInternational: Bool, days: Int) -> [PackingItem] {
        var items: [PackingItem] = [
            // 必需品
            PackingItem("現金", category: "必需品"),
            PackingItem("クレジットカード", category: "必需品"),
            PackingItem("身分証明書", category: "必需品"),
            PackingItem("健康保険証・お薬手帳", category: "必需品"),
            PackingItem("常備薬・医薬品", category: "必需品"),
            PackingItem("スマートフォン充電器", category: "必需品"),
            PackingItem("モバイルバッテリー", category: "必需品"),
            PackingItem("乗車券・施設の入場チケット", category: "必需品"),
            PackingItem("日程表", category: "必需品"),
            PackingItem("コンタクトレンズ用品・メガネ", category: "必需品"),
            PackingItem("緊急連絡先のメモ", category: "必需品"),

            // スーツケース・鞄
            PackingItem("スーツケース", category: "スーツケース・鞄"),
            PackingItem("ネームタグ", category: "スーツケース・鞄"),
            PackingItem("スーツケースベルト", category: "スーツケース・鞄"),
            PackingItem("折りたたみバッグ・エコバッグ", category: "スーツケース・鞄"),

            // 移動中に
            PackingItem("ネックピロー・旅行用枕", category: "移動中に"),
            PackingItem("アイマスク", category: "移動中に"),
            PackingItem("マスク", category: "移動中に"),
            PackingItem("耳栓", category: "移動中に"),
            PackingItem("リップクリーム", category: "移動中に"),
            PackingItem("ガイドブック・地図", category: "移動中に"),
            PackingItem("筆記用具・メモ帳", category: "移動中に"),

            // 観光・街歩き
            PackingItem("カメラ・充電器", category: "観光・街歩き"),
            PackingItem("折り畳み傘・日傘・レインコート", category: "観光・街歩き"),
            PackingItem("日焼け止め", category: "観光・街歩き"),
            PackingItem("サングラス", category: "観光・街歩き"),
            PackingItem("帽子", category: "観光・街歩き"),
            PackingItem("虫よけスプレー", category: "観光・街歩き"),
            PackingItem("ハンカチ・ハンドタオル", category: "観光・街歩き"),
            PackingItem("ポケットティッシュ", category: "観光・街歩き"),

            // 宿泊時に
            PackingItem("歯ブラシセット", category: "宿泊時に"),
            PackingItem("化粧品・スキンケア用品", category: "宿泊時に"),
            PackingItem("シャンプー・ボディソープ", category: "宿泊時に"),
            PackingItem("ヘアドライヤー", category: "宿泊時に"),
            PackingItem("ヘアブラシ・ヘアアイロン", category: "宿泊時に"),
            PackingItem("洗濯用品", category: "宿泊時に"),
            PackingItem("生理用品", category: "宿泊時に"),
            PackingItem("目覚まし時計", category: "宿泊時に"),

            // 衣類
            PackingItem("上着", category: "衣類"),
            PackingItem("下着", category: "衣類"),
            PackingItem("靴下・タイツ", category: "衣類"),
            PackingItem("着替え（\(max(days, 1))日分）", category: "衣類"),
            PackingItem("ルームウェア・パジャマ", category: "衣類"),

            // 感染症対策
            PackingItem("消毒・除菌シート", category: "感染症対策"),
            PackingItem("手指消毒スプレー・ジェル", category: "感染症対策")
        ]

        if isInternational {
            items += [
                PackingItem("パスポート", category: "必需品"),
                PackingItem("ビザ・電子渡航認証（ESTA等）", category: "必需品"),
                PackingItem("海外旅行保険の保険証", category: "必需品"),
                PackingItem("現地通貨", category: "必需品"),
                PackingItem("パスポート等証明書のコピー", category: "必需品"),
                PackingItem("海外用電源プラグ変換アダプター", category: "宿泊時に"),
                PackingItem("変圧器", category: "宿泊時に")
            ]
        } else {
            items.append(PackingItem("交通系ICカード", category: "観光・街歩き"))
        }

        return items
    }

    private static func climateItems(for category: ClimateCategory) -> [PackingItem] {
        switch category {
        case .cold:
            return [
                PackingItem("厚手のコート", category: "衣類"),
                PackingItem("手袋", category: "衣類"),
                PackingItem("マフラー", category: "衣類"),
                PackingItem("カイロ", category: "観光・街歩き")
            ]
        case .cool:
            return [PackingItem("長袖の羽織りもの", category: "衣類")]
        case .mild:
            return [PackingItem("薄手の羽織りもの", category: "衣類")]
        case .warm:
            return [PackingItem("半袖シャツ", category: "衣類")]
        case .hot:
            return [
                PackingItem("半袖シャツ", category: "衣類"),
                PackingItem("携帯扇風機・冷却シート・制汗剤", category: "観光・街歩き")
            ]
        }
    }

    private static func tripTypeItems(for tripType: TripType) -> [PackingItem] {
        switch tripType {
        case .sightseeing:
            return [PackingItem("歩きやすい靴", category: "衣類")]
        case .business:
            return [
                PackingItem("名刺", category: "必需品"),
                PackingItem("スーツ・フォーマルウェア", category: "衣類"),
                PackingItem("ノートPC・充電器", category: "観光・街歩き")
            ]
        case .outdoor:
            return [
                PackingItem("登山靴・運動靴", category: "衣類"),
                PackingItem("タオル", category: "観光・街歩き")
            ]
        case .onsen:
            return [PackingItem("館内着・浴衣の下に着るインナー", category: "衣類")]
        }
    }
}
