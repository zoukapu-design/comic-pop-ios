import SwiftUI

/// Second reference screen: genre selection, persistent consistency hints and
/// an actual generation entry point (offline or the user's Workers Free account).
struct PopGenreScreen: View {
    @ObservedObject var store:StudioStore
    var review: () -> Void
    var openSettings: () -> Void
    @State private var askGeneration = false
    @AppStorage("pop.story.useVoice") private var useVoice = true
    @AppStorage("pop.story.useVisualAI") private var useVisualAI = true
    @AppStorage("pop.hint.character") private var characterHint = true
    @AppStorage("pop.hint.palette") private var paletteHint = true
    @AppStorage("pop.hint.scene") private var sceneHint = false
    @AppStorage("pop.hint.fidelity") private var fidelityHint = false

    private let genres:[(id:String,title:String)] = [
        ("american","アメコミ系"),("shonen","熱血少年漫画"),
        ("shojo","少女漫画"),("gag","ギャグ漫画"),
        ("seinen","劇画・シネマ"),("horror","ホラー")
    ]

    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(alignment:.leading,spacing:10) {
                hero
                PopSurface {
                    VStack(alignment:.leading,spacing:9) {
                        HStack(spacing:6) {
                            PopBlueTitle(icon:"movieclapper.fill",title:"画風 / ジャンル選択")
                            Text("マンガの画風を\n選んでください！")
                                .font(.system(size:10,weight:.bold,design:.rounded))
                                .foregroundStyle(PopColor.ink)
                                .multilineTextAlignment(.center)
                        }
                        LazyVGrid(columns:[GridItem(.flexible(),spacing:8),
                                           GridItem(.flexible(),spacing:8)],spacing:9) {
                            ForEach(genres.indices,id:\.self) { i in
                                let genre=genres[i]
                                Button {store.updateStyle(genre.id)} label: {
                                    PopIllustratedCard(title:genre.title,artIndex:i,kind:.genres,
                                                       selected:store.data.style==genre.id)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                PopSurface {
                    VStack(alignment:.leading,spacing:9) {
                        HStack(spacing:6) {
                            PopBlueTitle(icon:"bolt.fill",title:"統一感アップ")
                            Text("作品の見た目をそろえる\n実験的なAI指示です")
                                .font(.system(size:10,weight:.medium))
                                .foregroundStyle(PopColor.ink)
                        }
                        HStack(spacing:4) {
                            option("同一キャラ維持",enabled:$characterHint)
                            option("色調を統一",enabled:$paletteHint)
                        }
                        HStack(spacing:4) {
                            option("場面切替を優先",enabled:$sceneHint)
                            option("元動画に忠実",enabled:$fidelityHint)
                        }
                        HStack(spacing:7) {
                            Text("色の設定").font(.system(size:12,weight:.bold))
                            PopPill(text:"白黒",icon:"circle.lefthalf.filled",
                                    selected:store.data.colorMode=="mono") {
                                store.updateColor("mono")
                            }
                            PopPill(text:"カラー",icon:"paintpalette",
                                    selected:store.data.colorMode=="color") {
                                store.updateColor("color")
                            }
                        }
                        .foregroundStyle(PopColor.ink)
                        HStack {
                            Text("タイトル").font(.system(size:11,weight:.bold))
                            TextField("作品タイトル（任意）",text:Binding(
                                get:{store.titleDraft},set:{store.updateTitle($0)}
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size:12))
                        }
                        .foregroundStyle(PopColor.ink)
                        VStack(alignment:.leading,spacing:5) {
                            Toggle("動画のシーンをAIで理解して脚本に使う",isOn:$useVisualAI)
                                .font(.system(size:12,weight:.bold))
                                .tint(PopColor.blue)
                            Text("AIモードでは、選んだ場面の一覧画像をあなたのCloudflare AIに送り、人物・行動・場面の流れを解釈します。非対応時は従来の文字情報から脚本を作ります。無料枠を使います。")
                                .font(.system(size:10))
                            Toggle("動画の日本語音声も物語に使う",isOn:$useVoice)
                                .font(.system(size:12,weight:.bold))
                                .tint(PopColor.blue)
                            Text("オンの場合、端末内の日本語音声認識の許可を求めます。音声認識不可でも動画の場面・カード・入力したメモから脚本を作ります。")
                                .font(.system(size:10))
                        }
                        Text("※AI生成は先に全カードから一つのストーリーを組み立て、それに沿って各コマを描きます。設定は人物一致などを保証するものではありません。")
                            .font(.system(size:10)).foregroundStyle(PopColor.ink.opacity(0.75))
                    }
                }
                if store.storyboardReady {
                    PopStoryboardDraft(store:store) {
                        Task {
                            await store.generate()
                            if !store.pageImages.isEmpty {review()}
                        }
                    }
                } else {
                    PopYellowButton(title:"この画風で漫画を作る",
                                    icon:"movieclapper.fill",
                                    enabled:!store.isGenerating && !store.data.pins.isEmpty) {
                        askGeneration=true
                    }
                }
                if store.isGenerating {
                    VStack(alignment:.leading,spacing:8) {
                        HStack(spacing:8) {
                            ProgressView().tint(PopColor.yellow)
                            Text("漫画を生成中：\(store.generated.count)/\(store.scenePlan.renderedPanelCount) シーン")
                                .font(.system(size:13,weight:.black,design:.rounded))
                        }
                        Text(store.message)
                            .font(.system(size:11,weight:.medium))
                        Text("終了までこの画面を開いてください。まだ完成していないコマは保存されません。")
                            .font(.system(size:10))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .padding(13)
                    .background(PopColor.navy.opacity(0.72),in:RoundedRectangle(cornerRadius:12))
                } else {
                    Text(store.data.pins.isEmpty ? "編集画面でカードを刺すと生成できます。" :
                         "カード\(store.data.pins.count)枚 → \(store.scenePlan.renderedPanelCount)シーン・\(store.scenePlan.pages)ページ。同じ場面の複数カードは演出を合成します。")
                        .font(.system(size:11,weight:.medium)).foregroundStyle(.white)
                }
            }
            .padding(.horizontal,10).padding(.bottom,16)
        }
        .confirmationDialog("漫画の生成方法を選ぶ",isPresented:$askGeneration,titleVisibility:.visible) {
            Button("無料でおためし生成（端末内・AIなし）") {
                Task {
                    await store.generateOffline()
                    if !store.pageImages.isEmpty {review()}
                }
            }
            Button("Cloudflare AI：まず脚本を確認してから漫画化") {
                guard store.tokenExists && store.confirmsFree else {
                    openSettings()
                    return
                }
                Task {
                    await store.prepareStoryboard()
                }
            }
            Button("キャンセル",role:.cancel) {}
        } message: {
            Text("AIモードはまず動画と複合カードから脚本を生成し、画面で確認・セリフ修正してから、別操作で漫画の絵を生成します。高品質映像理解ONでは選んだ場面の一覧画像をCloudflareへ送信します。脚本AI＋シーン数分の画像AI利用枠を消費し、非対応時の脚本再試行で増える場合があります。端末内モードは画像送信なしです。")
        }
    }

    private var hero: some View {
        ZStack(alignment:.leading) {
            PopArtwork(kind:.hero).frame(height:135)
                .overlay(LinearGradient(colors:[PopColor.royal.opacity(0.7),.clear],
                                        startPoint:.leading,endPoint:.trailing))
                .clipShape(RoundedRectangle(cornerRadius:18))
            VStack(alignment:.leading,spacing:3) {
                Image(systemName:"movieclapper.fill")
                    .font(.system(size:24,weight:.black))
                Text("画風を選ぶ")
                    .font(.system(size:26,weight:.black,design:.rounded))
                    .minimumScaleFactor(0.8)
                    .shadow(color:PopColor.navy,radius:3,x:2,y:2)
                Text("レックスとマンガを作ろう！")
                    .font(.system(size:11,weight:.bold))
            }
            .foregroundStyle(PopColor.yellow).padding(15)
        }
        .overlay(RoundedRectangle(cornerRadius:18).stroke(PopColor.edge,lineWidth:2))
    }
    private func option(_ label:String,enabled:Binding<Bool>)->some View {
        Button {enabled.wrappedValue.toggle()} label: {
            HStack(spacing:4) {
                Image(systemName:enabled.wrappedValue ? "checkmark.circle.fill" : "circle")
                Text(label).font(.system(size:10,weight:.heavy,design:.rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(PopColor.ink)
            .frame(maxWidth:.infinity)
            .padding(.vertical,9)
            .background(enabled.wrappedValue ? PopColor.yellow : Color.white,in:Capsule())
            .overlay(Capsule().stroke(enabled.wrappedValue ? PopColor.yellow : PopColor.edge,lineWidth:1.6))
        }.buttonStyle(.plain)
    }
}
