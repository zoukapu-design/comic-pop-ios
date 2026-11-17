import SwiftUI

/// Second reference screen: genre selection, persistent consistency hints and
/// an actual generation entry point (offline or the user's Workers Free account).
struct PopGenreScreen: View {
    @ObservedObject var store:StudioStore
    var review: () -> Void
    var openSettings: () -> Void
    @State private var askGeneration = false
    @State private var askResetFinished = false
    @State private var askAppearanceReset = false
    @State private var pendingAppearance: AppearanceChange?

    private enum AppearanceChange {
        case style(String)
        case color(String)
    }

    private func requestAppearance(_ choice:AppearanceChange) {
        let same:Bool
        switch choice {
        case .style(let value): same=store.data.style == value
        case .color(let value): same=store.data.colorMode == value
        }
        switch MangaAppearanceChangePolicy.decide(
            isGenerating:store.isGenerating,
            hasUncommittedGeneration:store.hasUncommittedGeneration,
            isSameSelection:same
        ) {
        case .unchanged, .blockedWhileGenerating:
            return
        case .applyNow:
            applyAppearance(choice)
        case .needsDiscardConfirmation:
            pendingAppearance=choice
            askAppearanceReset=true
        }
    }

    private func applyAppearance(_ choice:AppearanceChange) {
        switch choice {
        case .style(let value): store.updateStyle(value)
        case .color(let value): store.updateColor(value)
        }
    }
    @AppStorage("pop.story.useVoice") private var useVoice = true
    @AppStorage("pop.story.useVisualAI") private var useVisualAI = true
    @AppStorage("pop.hint.character") private var characterHint = true
    @AppStorage("pop.hint.palette") private var paletteHint = true
    @AppStorage("pop.hint.scene") private var sceneHint = true
    @AppStorage("pop.generation.sourceLocked.v1") private var sourceLocked = true

    private var generationRoute:MangaGenerationRoute {
        MangaGenerationRoute.resolve(
            hasCompleteComic:store.hasCompleteComic,
            generatedPanelCount:store.generatedPanelCount,
            generatedOffline:store.generatedOffline,
            storyboardReady:store.storyboardReady
        )
    }

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
                                Button {requestAppearance(.style(genre.id))} label: {
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
                            option("元動画に忠実",enabled:$sourceLocked)
                        }
                        HStack(spacing:7) {
                            Text("色の設定").font(.system(size:12,weight:.bold))
                            PopPill(text:"白黒",icon:"circle.lefthalf.filled",
                                    selected:store.data.colorMode=="mono") {
                                requestAppearance(.color("mono"))
                            }
                            PopPill(text:"カラー",icon:"paintpalette",
                                    selected:store.data.colorMode=="color") {
                                requestAppearance(.color("color"))
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
                            .submitLabel(.done)
                            .onSubmit {store.refreshPageTitle()}
                        }
                        .foregroundStyle(PopColor.ink)
                        VStack(alignment:.leading,spacing:5) {
                            Toggle("動画のシーンをAIで理解して脚本に使う",isOn:$useVisualAI)
                                .font(.system(size:12,weight:.bold))
                                .tint(PopColor.blue)
                            Text("AIモードでは、選んだ場面の一覧画像をあなたのCloudflare AIに送り、人物・行動・場面の流れを解釈します。画像AIモデルが非対応の場合のみ文字情報からの脚本に切り替えます。通信・脚本エラーでは追加のAI呼出しを自動実行しません。無料枠を使います。")
                                .font(.system(size:10))
                            Toggle("動画の日本語音声も物語に使う",isOn:$useVoice)
                                .font(.system(size:12,weight:.bold))
                                .tint(PopColor.blue)
                            Text("オンの場合、端末内の日本語音声認識の許可を求めます。音声認識不可でも動画の場面・カード・入力したメモから脚本を作ります。")
                                .font(.system(size:10))
                        }
                        Text(sourceLocked ? "推奨：人物・服装・道具・背景・構図は元動画のまま、漫画の線画とトーンに変換します。AIの完全な一致は保証できません。": "創作モード：AIが新たな構図や表現を作る場合があります。元動画との一致を重視する場合は「元動画に忠実」をONにしてください。")
                            .font(.system(size:10)).foregroundStyle(PopColor.ink.opacity(0.75))
                    }
                }
                if generationRoute == .viewCompleted {
                    PopSurface(accent:true) {
                        VStack(alignment:.leading,spacing:9) {
                            Label("漫画が完成しています",systemImage:"checkmark.seal.fill")
                                .font(.system(size:15,weight:.black,design:.rounded))
                            Text("\(store.generatedPanelCount)コマ・\(store.pageImages.count)ページが完成済みです。再生成せずにレビューへ戻れます。")
                                .font(.system(size:11,weight:.medium))
                            PopYellowButton(title:"完成した漫画を見る",
                                            icon:"book.pages.fill",action:review)
                            Button {
                                askResetFinished=true
                            } label: {
                                Label("この生成結果をリセット",systemImage:"trash")
                                    .font(.system(size:11,weight:.semibold))
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.isGenerating)
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                } else if generationRoute == .resumeOnline || generationRoute == .resumeOffline {
                    PopSurface(accent:true) {
                        VStack(alignment:.leading,spacing:8) {
                            Label("途中まで生成した漫画があります",systemImage:"arrow.clockwise")
                                .font(.system(size:14,weight:.black,design:.rounded))
                            Text("\(store.generatedPanelCount)/\(store.scenePlan.renderedPanelCount)コマ生成済み。完成済みのコマを再利用し、残りだけ処理します。")
                                .font(.system(size:11,weight:.medium))
                            if store.hasRecoverableDraft {
                                Label("端末に自動保存済み。アプリを再起動しても続きから再開できます。",
                                      systemImage:"internaldrive.fill")
                                    .font(.system(size:10,weight:.semibold))
                                    .foregroundStyle(PopColor.royal)
                            }
                            PopYellowButton(title:"続きを生成する",
                                            icon:"arrow.clockwise",
                                            enabled:!store.isGenerating) {
                                Task {
                                    if generationRoute == .resumeOffline {
                                        await store.generateOffline()
                                    } else {
                                        await store.generate()
                                    }
                                    if !store.pageImages.isEmpty {review()}
                                }
                            }
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                } else if generationRoute == .reviewStoryboard {
                    if store.hasRecoverableDraft {
                        Text("脚本はこのiPhoneに保存されています。作画前に編集できます。")
                            .font(.system(size:11,weight:.medium))
                            .foregroundStyle(.white)
                    }
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
        .confirmationDialog("生成済みの漫画・脚本を破棄しますか？",
                            isPresented:$askAppearanceReset,titleVisibility:.visible) {
            Button("生成結果を破棄して設定を変更",role:.destructive) {
                guard !store.isGenerating, let choice=pendingAppearance else {return}
                store.discardGenerated()
                applyAppearance(choice)
                pendingAppearance=nil
            }
            Button("キャンセル",role:.cancel) {pendingAppearance=nil}
        } message: {
            Text("画風や色を変えると、保存前の生成画像とAI脚本は消えます。挿入カード・動画・保存済みの作品は保持されます。")
        }
        .confirmationDialog("完成済み漫画をリセットしますか？",
                            isPresented:$askResetFinished,titleVisibility:.visible) {
            Button("生成結果を破棄して作り直す",role:.destructive) {
                store.discardGenerated()
            }
            Button("キャンセル",role:.cancel) {}
        } message: {
            Text("生成した画像と脚本を破棄します。カードと動画、作品一覧に保存済みの漫画は保持されます。保存前の完成作品は失われます。")
        }
        .confirmationDialog("漫画の生成方法を選ぶ",isPresented:$askGeneration,titleVisibility:.visible) {
            Button("無料でおためし生成（端末内・AIなし）") {
                Task {
                    await store.generateOffline()
                    if !store.pageImages.isEmpty {review()}
                }
            }
            Button("Cloudflare AI：まず脚本を確認してから漫画化") {
                guard CloudflareSetupPolicy.mayGenerateWithAI(
                    hasSavedToken:store.tokenExists,
                    accountID:store.cloudflareAccount,
                    didConfirmWorkersFree:store.confirmsFree
                ) else {
                    openSettings()
                    return
                }
                Task {
                    await store.prepareStoryboard()
                }
            }
            Button("キャンセル",role:.cancel) {}
        } message: {
            Text("AIモードはまず脚本を生成し、内容とセリフを確認してから別操作で画像を生成します。高品質映像理解ONでは選んだ場面の一覧画像をCloudflareへ送信します。モデル非対応の場合だけ、文字情報による脚本生成を自動で追加実行することがあります。サーバー障害や不完全な脚本では追加実行しません。端末内モードは画像送信なしです。")
        }
        .onDisappear {store.refreshPageTitle()}
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
