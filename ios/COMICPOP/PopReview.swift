import SwiftUI

/// Third reference screen: comparison with real source frames, real manga
/// page previews and working image adjustments. No fabricated AI quality scores.
struct PopReviewScreen: View {
    @ObservedObject var store:StudioStore
    var backToStyles: () -> Void
    var showWorks: () -> Void
    @State private var page = 0
    @State private var selectedPanel:UUID?
    @State private var fullScreen = false
    @State private var confirmRegenerate = false
    @State private var editingLettering:PreviewPanel?
    @State private var contrast = 1.05
    @State private var brightness = 0.0
    @State private var saturation = 1.0
    @State private var sharpness = 0.2

    private var actualPage: Int {min(page,max(0,store.pageImages.count-1))}
    private var topPanels: [PreviewPanel] {Array(store.generated.prefix(3))}
    private var activePanel: PreviewPanel? {
        store.generated.first(where:{$0.id==selectedPanel}) ?? store.generated.first
    }

    var body:some View {
        ScrollView(showsIndicators:false) {
            VStack(alignment:.leading,spacing:10) {
                hero
                if store.generated.isEmpty {
                    PopSurface {
                        VStack(spacing: 10) {
                            Image(systemName:"book.closed.fill")
                                .font(.system(size:32))
                                .foregroundStyle(PopColor.blue)
                            Text("まだマンガが生成されていません")
                                .font(.system(size:15,weight:.black))
                            Text("編集画面でカードを挿し、画風を選んで生成してください。")
                                .font(.system(size:12))
                                .multilineTextAlignment(.center)
                            PopYellowButton(title:"画風選択へ",icon:"paintbrush",action:backToStyles)
                        }
                        .foregroundStyle(PopColor.ink)
                        .frame(maxWidth:.infinity)
                        .padding(12)
                    }
                }
                if !topPanels.isEmpty {
                    if !store.storySummary.isEmpty {
                        PopSurface {
                            VStack(alignment:.leading,spacing:5) {
                                Text("今回の漫画ストーリー")
                                    .font(.system(size:13,weight:.black,design:.rounded))
                                Text(store.storySummary)
                                    .font(.system(size:12))
                                Text(store.storyCreationMode)
                                    .font(.system(size:10,weight:.medium))
                                    .foregroundStyle(PopColor.royal)
                            }
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .foregroundStyle(PopColor.ink)
                        }
                    }
                    comparison
                    panelChooser
                    PopSurface {
                        VStack(alignment:.leading,spacing:7) {
                            Label("日本語の確認",systemImage:"character.book.closed.fill")
                                .font(.system(size:13,weight:.black))
                            Text("AIが書いた意味不明な文章が残っている場合、未確認のAI文字だけを非表示にできます。元動画・絵・手動編集した文字は保持し、AI利用枠は消費しません。")
                                .font(.system(size:11,weight:.medium))
                            Button {
                                store.useOnlyVerifiedLettering()
                            } label:{
                                Label("未確認のAI日本語を非表示（無料）",
                                      systemImage:"text.badge.minus")
                                    .font(.system(size:12,weight:.heavy))
                                    .frame(maxWidth:.infinity)
                                    .padding(.vertical,10)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(PopColor.royal)
                            .background(.white,in:RoundedRectangle(cornerRadius:10))
                            .overlay(RoundedRectangle(cornerRadius:10)
                                .stroke(PopColor.edge,lineWidth:1.5))
                            .disabled(store.isGenerating)
                        }
                        .foregroundStyle(PopColor.ink)
                        .frame(maxWidth:.infinity,alignment:.leading)
                    }
                }
                if let firstRepeated=store.generated.first(where:{$0.warning != nil}) {
                    PopSurface(accent:true) {
                        VStack(alignment:.leading,spacing:8) {
                            Label("似すぎたコマを検出しました",systemImage:"exclamationmark.triangle.fill")
                                .font(.system(size:14,weight:.black,design:.rounded))
                            Text(firstRepeated.warning ?? "前の場面とほぼ同じ画像です。")
                                .font(.system(size:11))
                            Text("別の場面なら「コマ単位で再生成」を選び、違う構図を試してください。自動で追加のAI利用枠は消費しません。")
                                .font(.system(size:10))
                            Button {
                                selectedPanel=firstRepeated.id
                            } label: {
                                Label("このコマを選択",systemImage:"photo.on.rectangle")
                                    .font(.system(size:12,weight:.heavy))
                            }
                            .buttonStyle(.borderedProminent).tint(PopColor.blue)
                        }.foregroundStyle(PopColor.ink)
                    }
                }
                if !store.pageImages.isEmpty {finishedPage}
                if !store.hasCompleteComic {
                    PopSurface(accent:true) {
                        VStack(alignment:.leading,spacing:8) {
                            Label("まだ漫画が完成していません",systemImage:"exclamationmark.triangle.fill")
                                .font(.system(size:15,weight:.black))
                            Text("\(store.generated.count)/\(store.scenePlan.renderedPanelCount)シーン生成済み。未完成ページは保存できません。")
                                .font(.caption)
                            Button("画風選択に戻って生成を再開") {backToStyles()}
                                .buttonStyle(.borderedProminent).tint(PopColor.blue)
                        }.foregroundStyle(PopColor.ink)
                    }
                }
                HStack(spacing:8) {
                    PopYellowButton(title:"作品に保存",icon:"square.and.arrow.down",
                                    enabled:store.hasCompleteComic) {
                        if store.saveWork() {showWorks()}
                    }
                    Button {backToStyles()} label:{
                        Label("画風を変更",systemImage:"paintbrush.fill")
                            .font(.system(size:12,weight:.black))
                            .padding(9)
                            .background(.white,in:Capsule())
                            .foregroundStyle(PopColor.ink)
                    }.buttonStyle(.plain)
                }
                Text(store.message)
                    .font(.system(size:11,weight:.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal,5)
            }.padding(.horizontal,9).padding(.bottom,14)
        }
        .fullScreenCover(isPresented:$fullScreen) {
            ZStack(alignment:.topTrailing) {
                Color.black.ignoresSafeArea()
                if !store.pageImages.isEmpty {
                    ScrollView([.vertical,.horizontal]) {
                        Image(uiImage:store.pageImages[actualPage])
                            .resizable().scaledToFit()
                            .frame(maxWidth:.infinity).padding()
                    }
                }
                Button {fullScreen=false} label:{
                    Label("閉じる",systemImage:"xmark.circle.fill")
                        .font(.headline).foregroundStyle(.white)
                        .padding().background(.black.opacity(0.6),in:Capsule())
                }.padding()
            }
        }
        .sheet(item:$editingLettering) { panel in
            PopPanelLetteringSheet(store:store,panel:panel)
        }
        .confirmationDialog("選んだコマを再生成しますか？",isPresented:$confirmRegenerate) {
            Button(store.generatedOffline ? "端末内で再加工" : "Cloudflare AIで再生成") {
                guard let id=activePanel?.id else{return}
                Task {await store.regeneratePanel(id)}
            }
            Button("元動画に忠実な漫画加工（AI追加消費なし）") {
                if let id=activePanel?.id {store.chooseSourceFaithfulComic(id)}
            }
            Button("元動画の画像に戻す") {
                if let id=activePanel?.id {store.chooseOriginal(id)}
            }
            Button("キャンセル",role:.cancel){}
        } message:{
            Text(store.generatedOffline ?
                 "端末内加工は無料です。" :
                 "AI再生成はCloudflareの利用枠を追加消費します。元動画と人物・道具・背景が違う場合は「元動画に忠実な漫画加工」を選んでください。追加のAI利用枠は消費しません。")
        }
    }

    private var hero:some View {
        HStack(spacing:6) {
            VStack(alignment:.leading,spacing:4) {
                Text("漫画生成レビュー")
                    .font(.system(size:20,weight:.black,design:.rounded))
                Text("クオリティ改善")
                    .font(.system(size:23,weight:.black,design:.rounded))
                    .foregroundStyle(PopColor.yellow)
                Text("動画と生成したマンガを見比べて確認しよう！")
                    .font(.system(size:10,weight:.bold))
                HStack(spacing:3) {
                    Image(systemName:"checkmark.seal.fill")
                    Text(store.generatedOffline ? "端末内おためし" : "Cloudflare AI作画")
                }
                .font(.system(size:10,weight:.heavy))
                .padding(.horizontal,9).padding(.vertical,5)
                .background(PopColor.yellow,in:Capsule())
                .foregroundStyle(PopColor.ink)
            }
            .foregroundStyle(.white)
            Spacer(minLength:0)
            PopArtwork(kind:.hero).frame(width:100,height:111)
                .clipShape(RoundedRectangle(cornerRadius:12))
        }
        .padding(10)
        .frame(maxWidth:.infinity,alignment:.leading)
        .background(LinearGradient(colors:[PopColor.royal,PopColor.blue],
                                   startPoint:.leading,endPoint:.trailing),
                    in:RoundedRectangle(cornerRadius:16))
        .overlay(RoundedRectangle(cornerRadius:16).stroke(PopColor.edge,lineWidth:2))
    }

    private var comparison:some View {
        PopSurface {
            HStack(alignment:.top,spacing:6) {
                VStack(spacing:5) {
                    PopBlueTitle(icon:"play.rectangle.fill",title:"元の動画")
                    ForEach(topPanels) { panel in
                        Button {selectedPanel=panel.id} label:{
                            Image(uiImage:panel.original)
                                .resizable().scaledToFill().frame(height:65).clipped()
                                .clipShape(RoundedRectangle(cornerRadius:7))
                                .overlay(RoundedRectangle(cornerRadius:7)
                                    .stroke(activePanel?.id==panel.id ? PopColor.yellow : PopColor.edge,
                                            lineWidth:activePanel?.id==panel.id ? 3 : 1))
                        }.buttonStyle(.plain)
                    }
                }
                Image(systemName:"chevron.right.2")
                    .font(.system(size:18,weight:.heavy))
                    .foregroundStyle(PopColor.yellow)
                    .frame(width:18).padding(.top,80)
                VStack(spacing:5) {
                    PopBlueTitle(icon:"book.pages.fill",title:"生成マンガ")
                    ForEach(topPanels) { panel in
                        Button {selectedPanel=panel.id} label:{
                            Image(uiImage:panel.drawing)
                                .resizable().scaledToFill().frame(height:65).clipped()
                                .clipShape(RoundedRectangle(cornerRadius:7))
                                .overlay(RoundedRectangle(cornerRadius:7)
                                    .stroke(activePanel?.id==panel.id ? PopColor.yellow : PopColor.edge,
                                            lineWidth:activePanel?.id==panel.id ? 3 : 1))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .foregroundStyle(PopColor.ink)
            .padding(2)
        }
    }

    // Every inserted pin must be reachable for one-panel retakes, including
    // cards 4-12 which do not fit in the 3-frame comparison area.
    private var panelChooser: some View {
        PopSurface {
            VStack(alignment:.leading,spacing:7) {
                HStack {
                    Text("修正するコマを選ぶ")
                        .font(.system(size:13,weight:.black,design:.rounded))
                    Spacer()
                    Text("\(store.generated.count)コマ")
                        .font(.system(size:11,weight:.bold))
                }
                .foregroundStyle(PopColor.ink)
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:7) {
                        ForEach(Array(store.generated.enumerated()),id:\.element.id) { entry in
                            let current=entry.element
                            Button {selectedPanel=current.id} label: {
                                VStack(spacing:4) {
                                    Image(uiImage:current.drawing)
                                        .resizable().scaledToFill()
                                        .frame(width:84,height:63).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius:8))
                                    Text("\(entry.offset+1). \(current.cardTitle)")
                                        .font(.system(size:10,weight:.heavy))
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                        .frame(width:84)
                                }
                                .foregroundStyle(PopColor.ink)
                                .padding(5)
                                .background(.white,in:RoundedRectangle(cornerRadius:10))
                                .overlay(RoundedRectangle(cornerRadius:10)
                                    .stroke(activePanel?.id == current.id ? PopColor.yellow : PopColor.edge,
                                            lineWidth:activePanel?.id == current.id ? 3 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(entry.offset+1)コマ目 \(current.cardTitle) を選択")
                        }
                    }
                }
                if let current=activePanel {
                    Label("選択中：\(current.cardTitle)",systemImage:"checkmark.circle.fill")
                        .font(.system(size:11,weight:.heavy))
                        .foregroundStyle(PopColor.royal)
                }
            }
        }
    }

    private var finishedPage:some View {
        PopSurface {
            VStack(spacing:9) {
                HStack(spacing:7) {
                    PopBlueTitle(icon:"book.closed.fill",title:"完成したマンガ")
                    Button {page=max(0,page-1)} label:{
                        Image(systemName:"chevron.left.circle.fill")
                    }.disabled(page==0)
                    Text("\(actualPage+1)/\(store.pageImages.count)")
                        .font(.system(size:11,weight:.heavy,design:.monospaced))
                        .foregroundStyle(PopColor.ink)
                    Button {page=min(store.pageImages.count-1,page+1)} label:{
                        Image(systemName:"chevron.right.circle.fill")
                    }.disabled(page+1>=store.pageImages.count)
                    Button {fullScreen=true} label:{
                        Image(systemName:"arrow.up.left.and.arrow.down.right")
                    }
                }
                .buttonStyle(.plain).foregroundStyle(PopColor.royal)
                HStack(alignment:.top,spacing:7) {
                    VStack(spacing:6) {
                        Image(uiImage:store.pageImages[actualPage])
                            .resizable().scaledToFit().background(.white)
                            .overlay(Rectangle().stroke(PopColor.ink,lineWidth:1))
                        ScrollView(.horizontal,showsIndicators:false) {
                            HStack(spacing:5) {
                                ForEach(store.pageImages.indices,id:\.self) { i in
                                    Button {page=i} label:{
                                        Image(uiImage:store.pageImages[i])
                                            .resizable().scaledToFit().frame(width:44,height:58)
                                            .background(.white)
                                            .overlay(Rectangle().stroke(
                                                i==actualPage ? PopColor.yellow : PopColor.edge,
                                                lineWidth:i==actualPage ? 3 : 1))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth:.infinity)
                    qualityPanel.frame(width:148)
                }
            }
        }
    }

    private var qualityPanel:some View {
        VStack(alignment:.leading,spacing:7) {
            PopBlueTitle(icon:"gearshape.fill",title:"画質を調整")
            control("線の強さ",value:$contrast,range:0.7...1.7,format:{Int($0*100)})
            control("明るさ",value:$brightness,range:(-0.2)...0.2,format:{Int(($0+0.2)*250)})
            control("彩度",value:$saturation,range:0.0...1.6,format:{Int($0*100)})
            control("輪郭強調",value:$sharpness,range:0.0...1.5,format:{Int($0*100)})
            Button {if let panel=activePanel {editingLettering=panel}} label:{
                VStack(spacing:2) {
                    Image(systemName:"text.bubble.fill")
                    Text("日本語の\nセリフを編集")
                        .multilineTextAlignment(.center)
                }
                .font(.system(size:11,weight:.heavy,design:.rounded))
                .foregroundStyle(PopColor.ink)
                .frame(maxWidth:.infinity).padding(.vertical,7)
                .background(.white,in:RoundedRectangle(cornerRadius:10))
                .overlay(RoundedRectangle(cornerRadius:10)
                    .stroke(PopColor.edge,lineWidth:1.5))
            }
            .disabled(store.isGenerating || activePanel == nil)
            // AI sometimes bakes pseudo-Japanese straight into its pixels.
            // Editing a native caption cannot touch those glyphs. Offer an
            // explicit no-AI-credit replacement from the filmed video frame.
            Button {
                if let panel=activePanel {
                    store.chooseSourceFaithfulComic(panel.id)
                }
            } label:{
                VStack(spacing:3) {
                    Image(systemName:"text.badge.xmark")
                    Text("絵の中の偽文字を除去\n（元動画から再加工）")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal:false,vertical:true)
                }
                .font(.system(size:10,weight:.heavy,design:.rounded))
                .foregroundStyle(PopColor.ink)
                .frame(maxWidth:.infinity).padding(.vertical,8)
                .background(.white,in:RoundedRectangle(cornerRadius:10))
                .overlay(RoundedRectangle(cornerRadius:10)
                    .stroke(PopColor.edge,lineWidth:1.5))
            }
            .disabled(store.isGenerating || activePanel == nil)
            Button {confirmRegenerate=true} label:{
                VStack(spacing:2) {
                    Image(systemName:"arrow.clockwise")
                    Text("このコマだけ\n再生成")
                        .multilineTextAlignment(.center)
                }
                .font(.system(size:11,weight:.heavy,design:.rounded))
                .foregroundStyle(PopColor.ink)
                .frame(maxWidth:.infinity).padding(.vertical,7)
                .background(.white,in:RoundedRectangle(cornerRadius:10))
                .overlay(RoundedRectangle(cornerRadius:10).stroke(PopColor.edge,lineWidth:1.5))
            }
            .disabled(store.isGenerating)
            Button {
                store.applyFinishing(contrast:contrast,brightness:brightness,
                                     saturation:saturation,sharpness:sharpness)
            } label:{
                VStack(spacing:2) {
                    Image(systemName:"sparkles")
                    Text("ページ全体を\n最適化")
                        .multilineTextAlignment(.center)
                }
                .font(.system(size:12,weight:.black,design:.rounded))
                .foregroundStyle(PopColor.ink)
                .frame(maxWidth:.infinity).padding(.vertical,8)
                .background(PopColor.yellow,in:RoundedRectangle(cornerRadius:11))
                .overlay(RoundedRectangle(cornerRadius:11).stroke(.white,lineWidth:2))
            }
            .disabled(store.isGenerating || !store.hasCompleteComic)
            Text("※上記は描画フィルターの設定値です。人物一致率・場面検出率などの実測スコアではありません。")
                .font(.system(size:9)).foregroundStyle(PopColor.ink.opacity(0.7))
        }
        .padding(5)
        .background(Color(red:0.85,green:0.94,blue:1),in:RoundedRectangle(cornerRadius:12))
    }

    private func control(_ label:String,value:Binding<Double>,range:ClosedRange<Double>,
                         format:(Double)->Int)->some View {
        VStack(spacing:0) {
            HStack(spacing:2) {
                Text(label).font(.system(size:10,weight:.bold,design:.rounded))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength:0)
                Text("\(format(value.wrappedValue))%")
                    .font(.system(size:10,weight:.black,design:.monospaced))
                    .padding(.horizontal,4).padding(.vertical,2)
                    .background(PopColor.yellow,in:Capsule())
            }
            Slider(value:value,in:range).tint(PopColor.blue)
                .accessibilityLabel(label)
        }
        .foregroundStyle(PopColor.ink)
    }
}
