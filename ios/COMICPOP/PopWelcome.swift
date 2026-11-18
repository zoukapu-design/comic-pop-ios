import SwiftUI

/// First-launch welcome: actual buttons, same Rex and visual system as
/// the production editor. This intentionally appears only on first launch.
struct PopWelcomeScreen: View {
    let begin: () -> Void
    @State private var showHowTo = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators:false) {
                VStack(spacing:19) {
                    Spacer(minLength:18)
                    ZStack(alignment:.bottomLeading) {
                        PopArtwork(kind:.hero)
                            .frame(height:min(350,geo.size.height*0.50))
                            .clipShape(RoundedRectangle(cornerRadius:26))
                        LinearGradient(colors:[.clear,PopColor.navy.opacity(0.78)],
                                       startPoint:.center,endPoint:.bottom)
                            .clipShape(RoundedRectangle(cornerRadius:26))
                        VStack(alignment:.leading,spacing:5) {
                            Text("ムビコマ")
                                .font(.system(size:39,weight:.black,design:.rounded))
                                .foregroundStyle(PopColor.yellow)
                            Text("動画をマンガに変換！")
                                .font(.system(size:17,weight:.heavy,design:.rounded))
                                .foregroundStyle(.white)
                        }.shadow(color:PopColor.navy,radius:4,y:2).padding(18)
                    }
                    .overlay(RoundedRectangle(cornerRadius:26)
                        .stroke(PopColor.edge,lineWidth:3))
                    VStack(spacing:7) {
                        Text("動画が、すぐにマンガになる！")
                            .font(.system(size:20,weight:.black,design:.rounded))
                            .foregroundStyle(.white)
                        Text("動画を選んで、好きな場面にカードを刺し、画風を選ぼう。")
                            .font(.system(size:12,weight:.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.93))
                    }
                    PopYellowButton(title:"はじめる",icon:"play.fill",action:begin)
                    Button {showHowTo.toggle()} label:{
                        Label(showHowTo ? "使い方を閉じる" : "使い方を見る",
                              systemImage:"book.closed.fill")
                            .font(.system(size:15,weight:.black,design:.rounded))
                            .foregroundStyle(PopColor.ink)
                            .frame(maxWidth:.infinity).padding(13)
                            .background(.white,in:Capsule())
                            .overlay(Capsule().stroke(PopColor.edge,lineWidth:2))
                    }
                    .buttonStyle(.plain)
                    if showHowTo {
                        PopSurface {
                            VStack(alignment:.leading,spacing:10) {
                                howTo("1","動画を選ぶ","写真ライブラリやファイルから選択")
                                howTo("2","好きな場面にカードを刺す","再生しながらタップで挿入")
                                howTo("3","漫画に変換する","画風を選んで生成・保存")
                            }.foregroundStyle(PopColor.ink)
                        }
                    }
                    Spacer(minLength:8)
                }
                .padding(.horizontal,17)
                .frame(minHeight:geo.size.height)
            }
            .background(PopBackground())
        }
    }
    private func howTo(_ n:String,_ title:String,_ subtitle:String)->some View {
        HStack(spacing:10) {
            Text(n).font(.system(size:19,weight:.black))
                .frame(width:34,height:34)
                .background(PopColor.yellow,in:Circle())
            VStack(alignment:.leading,spacing:2) {
                Text(title).font(.system(size:13,weight:.black))
                Text(subtitle).font(.system(size:11,weight:.medium))
            }
            Spacer()
        }
    }
}
