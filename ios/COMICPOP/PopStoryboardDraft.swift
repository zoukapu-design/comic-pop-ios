import SwiftUI

/// Visible screenplay review before any image GPU quota is consumed.
/// All scene cards remain combined and all Japanese dialogue can be edited.
struct PopStoryboardDraft: View {
    @ObservedObject var store:StudioStore
    let drawComic: () -> Void
    @State private var editingBeat:MangaStoryBeat?
    @State private var confirmRewrite=false
    @State private var confirmDrawWithWarnings=false

    private var storyWarnings:[StoryReviewWarning] {
        MangaStoryQualityAudit.warnings(for:store.storyboardBeats.map {
            StoryReviewScene(
                index:$0.index,plot:$0.plotDescriptionJP,
                caption:$0.caption,
                imagePrompt:$0.userVisualDirection.isEmpty
                    ? $0.imagePrompt : $0.userVisualDirection,
                transition:$0.transition,
                narrativeRole:$0.narrativeDutyJP,
                causalLink:$0.causalLinkJP,
                requiresCausalLink:$0.index>1
            )
        })
    }

    var body:some View {
        PopSurface(accent:true) {
            VStack(alignment:.leading,spacing:10) {
                HStack(spacing:8) {
                    Image(systemName:"text.book.closed.fill")
                        .font(.system(size:20,weight:.black))
                    VStack(alignment:.leading,spacing:3) {
                        Text("マンガの脚本を確認")
                            .font(.system(size:17,weight:.black,design:.rounded))
                        Text("\(store.storyboardBeats.count)シーンのつながりを確認してから作画")
                            .font(.system(size:11,weight:.semibold))
                    }
                }
                .foregroundStyle(PopColor.ink)
                Text(store.storySummary)
                    .font(.system(size:12,weight:.heavy))
                    .foregroundStyle(PopColor.ink)
                    .frame(maxWidth:.infinity,alignment:.leading)
                Text(store.storyCreationMode)
                    .font(.system(size:10))
                    .foregroundStyle(PopColor.royal)
                if !storyWarnings.isEmpty {
                    VStack(alignment:.leading,spacing:5) {
                        Label("作画前に確認したい点（\(storyWarnings.count)件）",
                              systemImage:"exclamationmark.triangle.fill")
                            .font(.system(size:12,weight:.black))
                        ForEach(storyWarnings) { finding in
                            Text("シーン\(finding.sceneNumber)：\(finding.message)")
                                .font(.system(size:11,weight:.medium))
                        }
                        Text("これは簡易チェックです。AI漫画の品質を保証するスコアではありません。")
                            .font(.system(size:10))
                    }
                    .foregroundStyle(PopColor.ink)
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .padding(10)
                    .background(PopColor.yellow.opacity(0.25),
                                in:RoundedRectangle(cornerRadius:11))
                }

                ForEach(store.storyboardBeats) { beat in
                    let cards=store.scenePlan.scenes.first(where:{$0.id==beat.id})?
                        .pins.map{store.card(for:$0).title}.joined(separator:"＋") ?? "シーン"
                    VStack(alignment:.leading,spacing:6) {
                        HStack(alignment:.top,spacing:6) {
                            Text("SCENE \(beat.index)")
                                .font(.system(size:10,weight:.black,design:.monospaced))
                                .padding(.horizontal,7).padding(.vertical,4)
                                .foregroundStyle(PopColor.ink)
                                .background(PopColor.yellow,in:Capsule())
                            Text(cards)
                                .font(.system(size:13,weight:.black,design:.rounded))
                                .foregroundStyle(PopColor.ink)
                            Spacer()
                            Button {editingBeat=beat} label: {
                                Label("シーン修正",systemImage:"pencil")
                                    .font(.system(size:10,weight:.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(PopColor.blue)
                        }
                        if !beat.narrativeDutyJP.isEmpty {
                            Label("物語の役割：\(beat.narrativeDutyJP)",
                                  systemImage:"list.bullet.rectangle")
                                .font(.system(size:11,weight:.bold))
                                .foregroundStyle(PopColor.royal)
                        }
                        if !beat.plotDescriptionJP.isEmpty {
                            Text("このコマの出来事：\(beat.plotDescriptionJP)")
                                .font(.system(size:12,weight:.heavy))
                                .foregroundStyle(PopColor.royal)
                        }
                        if beat.index>1 {
                            Text(beat.causalLinkJP.isEmpty
                                 ? "前のコマとのつながり：未設定（シーン修正から追加できます）"
                                 : "前のコマとのつながり：\(beat.causalLinkJP)")
                                .font(.system(size:11,weight:.medium))
                                .foregroundStyle(PopColor.ink)
                        }
                        Text(beat.caption.isEmpty ? "（ナレーションなし）" : beat.caption)
                            .font(.system(size:12,weight:.medium))
                            .foregroundStyle(PopColor.ink)
                        if !beat.dialogue.isEmpty {
                            HStack(alignment:.top) {
                                Image(systemName:"bubble.left.fill")
                                Text(beat.dialogue)
                            }
                            .font(.system(size:12,weight:.semibold))
                            .foregroundStyle(PopColor.ink)
                        }
                        if !beat.userVisualDirection.isEmpty {
                            Label("作画指示：\(beat.userVisualDirection)",systemImage:"paintbrush.fill")
                                .font(.system(size:11,weight:.medium))
                                .foregroundStyle(PopColor.royal)
                        }
                    }
                    .padding(10)
                    .background(.white,in:RoundedRectangle(cornerRadius:12))
                    .overlay(RoundedRectangle(cornerRadius:12)
                        .stroke(PopColor.edge,lineWidth:1.5))
                }

                Text("この段階では脚本のみです。映像の全シーンをつなぐ内容が適切か確認してください。画像のAI作画は次のボタンを押してから始まります。")
                    .font(.system(size:11,weight:.medium))
                    .foregroundStyle(PopColor.ink)
                PopYellowButton(title:"この脚本で漫画の絵を描く",
                                icon:"paintbrush.pointed.fill",
                                enabled:!store.isGenerating) {
                    if storyWarnings.isEmpty {
                        drawComic()
                    } else {
                        confirmDrawWithWarnings=true
                    }
                }
                Button {confirmRewrite=true} label:{
                    Label("脚本を作り直す（AI利用枠を消費）",
                          systemImage:"arrow.clockwise")
                        .font(.system(size:11,weight:.bold))
                        .foregroundStyle(PopColor.ink)
                        .frame(maxWidth:.infinity)
                        .padding(.vertical,9)
                }
                .buttonStyle(.plain)
                .disabled(store.isGenerating)
            }
        }
        .sheet(item:$editingBeat) { beat in
            PopStoryboardTextEditor(beat:beat) { plot,caption,dialogue,direction,causal in
                store.updateStoryboardBeat(beat.id,caption:caption,dialogue:dialogue,
                                           plotDescription:plot,visualDirection:direction,
                                           causalLink:causal)
            }
        }
        .confirmationDialog("作画前の注意点があります",
                            isPresented:$confirmDrawWithWarnings,
                            titleVisibility:.visible) {
            Button("注意点を確認したうえで作画する") {drawComic()}
            Button("修正する",role:.cancel) {}
        } message: {
            Text("脚本に\(storyWarnings.count)件の確認点があります。内容を修正すれば画像生成枠の無駄を減らせます。今のまま進める場合はCloudflareの画像生成枠を使用します。")
        }
        .confirmationDialog("脚本を再作成しますか？",
                            isPresented:$confirmRewrite,
                            titleVisibility:.visible) {
            Button("再生成（CloudflareのAI利用枠を消費）") {
                Task {await store.recreateStoryboard()}
            }
            Button("キャンセル",role:.cancel) {}
        } message: {
            Text("元の脚本は新しい脚本が成功するまで保持します。画像生成は行いません。")
        }
        .accessibilityIdentifier("popStoryboardReviewBeforeDrawing")
    }
}

private struct PopStoryboardTextEditor:View {
    let beat:MangaStoryBeat
    let onSave:(String,String,String,String,String)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var plotDescription:String
    @State private var caption:String
    @State private var dialogue:String
    @State private var visualDirection:String
    @State private var causalLink:String

    init(beat:MangaStoryBeat,onSave:@escaping (String,String,String,String,String)->Void) {
        self.beat=beat
        self.onSave=onSave
        _plotDescription=State(initialValue:beat.plotDescriptionJP)
        _caption=State(initialValue:beat.caption)
        _dialogue=State(initialValue:beat.dialogue)
        _visualDirection=State(initialValue:beat.userVisualDirection)
        _causalLink=State(initialValue:beat.causalLinkJP)
    }

    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:13) {
                    PopBlueTitle(icon:"text.bubble.fill",
                                 title:"シーン\(beat.index)の展開とセリフを修正")
                    PopSurface {
                        VStack(alignment:.leading,spacing:10) {
                            Text("このコマで起きる出来事（ストーリー）")
                                .font(.system(size:13,weight:.black))
                            TextEditor(text:$plotDescription)
                                .frame(minHeight:100)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(.white,in:RoundedRectangle(cornerRadius:9))
                            Text("セリフとは別に、人物の行動と事件の結果を具体的に記入してください。")
                                .font(.system(size:11))
                            if beat.index>1 {
                                Text("前のコマとのつながり（原因・反応・結果）")
                                    .font(.system(size:13,weight:.black))
                                TextEditor(text:$causalLink)
                                    .frame(minHeight:75)
                                    .scrollContentBackground(.hidden)
                                    .padding(6)
                                    .background(.white,in:RoundedRectangle(cornerRadius:9))
                                Text("例：「そばを切ろうとして手が滑り、その音に驚いた」")
                                    .font(.system(size:11))
                            }
                            Text("ナレーション").font(.system(size:13,weight:.black))
                            TextEditor(text:$caption)
                                .frame(minHeight:100)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(.white,in:RoundedRectangle(cornerRadius:9))
                            Text("セリフ").font(.system(size:13,weight:.black))
                            TextEditor(text:$dialogue)
                                .frame(minHeight:90)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(.white,in:RoundedRectangle(cornerRadius:9))
                            Text("このシーンで何が起きる？ どのように描いてほしい？")
                                .font(.system(size:13,weight:.black))
                            TextEditor(text:$visualDirection)
                                .frame(minHeight:110)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(.white,in:RoundedRectangle(cornerRadius:9))
                            Text("例：「そば打ちが失敗しそうになった瞬間。主人公の青ざめた顔を大きく、背景は不穏な集中線で。ドラマティックと恐怖を同時に表現」")
                                .font(.system(size:11,weight:.medium))
                            Text("この指示はAIの元の脚本より優先します。セリフと描画指示の編集だけなら画像生成回数は増えません。")
                                .font(.system(size:11))
                            PopYellowButton(title:"脚本に反映",icon:"checkmark") {
                                onSave(plotDescription,caption,dialogue,visualDirection,causalLink)
                                dismiss()
                            }
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                }
                .padding(12)
            }
            .background(PopBackground())
            .navigationTitle("展開・日本語を編集")
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button("閉じる") {dismiss()}
                }
            }
        }
    }
}
