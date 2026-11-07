import SwiftUI

/// Story notes are part of the pin and have priority over automatic guesses.
struct PopPinStorySheet: View {
    @ObservedObject var store: StudioStore
    let pin: MangaPin
    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var dialogue: String

    init(store:StudioStore,pin:MangaPin) {
        self.store=store
        self.pin=pin
        _note=State(initialValue:pin.note)
        _dialogue=State(initialValue:pin.dialogue)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:13) {
                    PopBlueTitle(icon:"pencil.line",title:"カードの物語を指定")
                    PopSurface {
                        VStack(alignment:.leading,spacing:8) {
                            Text("\(store.formatted(pin.seconds)) · \(store.card(for:pin).title)")
                                .font(.system(size:16,weight:.black,design:.rounded))
                            Text("このカードを漫画のどんな展開にしたいですか？")
                                .font(.system(size:12,weight:.medium))
                            TextEditor(text:$note)
                                .frame(height:110)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(.white,in:RoundedRectangle(cornerRadius:12))
                                .overlay(RoundedRectangle(cornerRadius:12)
                                    .stroke(PopColor.edge,lineWidth:1.5))
                            Text("例：最初は陶芸がうまくいくと思っていたが、次の場面で大失敗の予感。")
                                .font(.system(size:11))
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                    PopSurface {
                        VStack(alignment:.leading,spacing:9) {
                            Text("この場面のセリフ（任意）")
                                .font(.system(size:15,weight:.black,design:.rounded))
                            TextField("例：えっ、ここからどうなるの!?",text:$dialogue,axis:.vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                            Text("ここに書いたセリフを優先して漫画に入れます。未入力ならAIがストーリーに合わせて考えます。")
                                .font(.system(size:11))
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                    Text("メモを保存すると、古い生成結果は無効になります。もう一度生成すると、更新した脚本が使われます。")
                        .font(.caption)
                        .foregroundStyle(.white)
                    PopYellowButton(title:"このカードの物語を保存",icon:"checkmark.circle.fill") {
                        store.updatePinStory(pin.id,note:note,dialogue:dialogue)
                        dismiss()
                    }
                }.padding(13)
            }
            .background(PopBackground())
            .navigationTitle("物語メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {ToolbarItem(placement:.topBarLeading) {
                Button("キャンセル") {dismiss()}
            }}
        }
    }
}

/// Corrects a Japanese caption in the generated manga without redrawing art.
struct PopPanelLetteringSheet: View {
    @ObservedObject var store: StudioStore
    let panel: PreviewPanel
    @Environment(\.dismiss) private var dismiss
    @State private var caption: String
    @State private var dialogue: String

    init(store:StudioStore,panel:PreviewPanel) {
        self.store=store
        self.panel=panel
        _caption=State(initialValue:panel.caption)
        _dialogue=State(initialValue:panel.dialogue)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    PopBlueTitle(icon:"text.bubble.fill",title:"日本語のセリフを修正")
                    PopSurface {
                        VStack(alignment:.leading,spacing:8) {
                            Text("\(panel.cardTitle) · ナレーション")
                                .font(.headline)
                            TextEditor(text:$caption)
                                .frame(height:104)
                                .scrollContentBackground(.hidden)
                                .background(.white,in:RoundedRectangle(cornerRadius:9))
                            Text("吹き出しのセリフ")
                                .font(.headline)
                            TextEditor(text:$dialogue)
                                .frame(height:96)
                                .scrollContentBackground(.hidden)
                                .background(.white,in:RoundedRectangle(cornerRadius:9))
                            Text("漫画画像はそのまま、日本語の文字だけを描き直します。AIの無料枠は消費しません。")
                                .font(.caption)
                        }
                        .foregroundStyle(PopColor.ink)
                    }
                    PopYellowButton(title:"このコマの文字を更新",icon:"checkmark.circle.fill") {
                        store.updatePanelText(panel.id,caption:caption,dialogue:dialogue)
                        dismiss()
                    }
                }.padding(13)
            }
            .background(PopBackground())
            .navigationTitle("セリフ編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {ToolbarItem(placement:.topBarLeading) {
                Button("キャンセル") {dismiss()}
            }}
        }
    }
}