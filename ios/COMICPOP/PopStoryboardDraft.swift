import SwiftUI

/// Visible screenplay review before any image GPU quota is consumed.
/// All scene cards remain combined and all Japanese dialogue can be edited.
struct PopStoryboardDraft: View {
    @ObservedObject var store:StudioStore
    let drawComic: () -> Void
    @State private var editingBeat:MangaStoryBeat?
    @State private var confirmRewrite=false

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
                                Label("セリフ修正",systemImage:"pencil")
                                    .font(.system(size:10,weight:.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(PopColor.blue)
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
                                enabled:!store.isGenerating,action:drawComic)
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
            PopStoryboardTextEditor(beat:beat) { caption,dialogue in
                store.updateStoryboardBeat(beat.id,caption:caption,dialogue:dialogue)
            }
        }
        .confirmationDialog("脚本を再作成しますか？",
                            isPresented:$confirmRewrite,
                            titleVisibility:.visible) {
            Button("再生成（CloudflareのAI利用枠を消費）") {
                Task {await store.prepareStoryboard()}
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
    let onSave:(String,String)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var caption:String
    @State private var dialogue:String

    init(beat:MangaStoryBeat,onSave:@escaping (String,String)->Void) {
        self.beat=beat
        self.onSave=onSave
        _caption=State(initialValue:beat.caption)
        _dialogue=State(initialValue:beat.dialogue)
    }

    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:13) {
                    PopBlueTitle(icon:"text.bubble.fill",
                                 title:"シーン\(beat.index)の日本語を修正")
                    PopSurface {
                        VStack(alignment:.leading,spacing:10) {
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
                            Text("この修正で画像生成回数は増えません。登場人物の行動を変えたい場合は、編集画面のカードメモで指定してから脚本を作り直してください。")
                                .font(.system(size:11))
                            PopYellowButton(title:"脚本に反映",icon:"checkmark") {
                                onSave(caption,dialogue)
                                dismiss()
                            }
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                }
                .padding(12)
            }
            .background(PopBackground())
            .navigationTitle("日本語の脚本を編集")
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button("閉じる") {dismiss()}
                }
            }
        }
    }
}
