import SwiftUI
import UIKit

/// Reusable, native comic UI. Layout is SwiftUI: the reference screens are NEVER
/// used as a background image or an unclickable full-screen bitmap.
enum PopColor {
    static let blue = Color(red: 0.01, green: 0.39, blue: 0.95)
    static let cyan = Color(red: 0.01, green: 0.79, blue: 1)
    static let royal = Color(red: 0.01, green: 0.23, blue: 0.69)
    static let navy = Color(red: 0.02, green: 0.10, blue: 0.31)
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.02)
    static let paper = Color(red: 0.91, green: 0.97, blue: 1.0)
    static let ink = Color(red: 0.02, green: 0.09, blue: 0.31)
    static let edge = Color(red: 0.42, green: 0.86, blue: 1.0)
}

struct PopBackground: View {
    var body: some View {
        GeometryReader { _ in
            ZStack {
                LinearGradient(colors: [PopColor.blue, PopColor.royal, PopColor.blue],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    // Light halftone, not a screenshot baked under interactive controls.
                    for x in stride(from: 0.0, through: Double(size.width), by: 13) {
                        for y in stride(from: 0.0, through: Double(size.height), by: 13) {
                            let radius: CGFloat = (Int(x/13+y/13) % 4 == 0) ? 2.3 : 1.3
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius*2, height: radius*2)),
                                         with: .color(.white.opacity(0.12)))
                        }
                    }
                }
                .accessibilityHidden(true)
            }
        }.ignoresSafeArea()
    }
}

struct PopSurface<Content: View>: View {
    var accent: Bool = false
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(9)
            .background(
                LinearGradient(colors: [Color.white, PopColor.paper, Color(red:0.75,green:0.91,blue:1)],
                               startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 19))
            )
            .overlay(RoundedRectangle(cornerRadius: 19)
                .stroke(accent ? PopColor.yellow : PopColor.edge, lineWidth: accent ? 3 : 2))
            .shadow(color: PopColor.navy.opacity(0.25), radius: 8, y: 4)
    }
}

struct PopBlueTitle: View {
    var icon: String
    var title: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 18, weight: .black))
            Text(title).font(.system(size: 18, weight: .black, design: .rounded))
                .minimumScaleFactor(0.75).lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13).padding(.vertical, 8)
        .background(LinearGradient(colors:[PopColor.blue,PopColor.royal], startPoint:.top, endPoint:.bottom),
                    in: Capsule())
        .overlay(Capsule().stroke(PopColor.edge, lineWidth: 1.8))
        .shadow(color:PopColor.royal.opacity(0.23),radius:4,y:2)
    }
}

struct PopYellowButton: View {
    var title: String
    var icon: String = "sparkles"
    var enabled: Bool = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 20, weight: .black))
                Text(title).font(.system(size: 19, weight: .black, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            .foregroundStyle(PopColor.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(LinearGradient(colors:[Color(red:1,green:0.97,blue:0.33),PopColor.yellow,Color(red:1,green:0.65,blue:0)],
                                       startPoint:.top,endPoint:.bottom), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.85),lineWidth:2))
            .overlay(Capsule().stroke(PopColor.yellow.opacity(0.8),lineWidth:3).padding(-3))
            .shadow(color:PopColor.yellow.opacity(0.4),radius:5,y:3)
            .opacity(enabled ? 1 : 0.52)
        }.disabled(!enabled).buttonStyle(.plain)
    }
}

struct PopPill: View {
    var text: String
    var icon: String
    var selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action:action) {
            HStack(spacing:4) {
                Image(systemName:icon).font(.system(size: 12,weight:.heavy))
                Text(text).font(.system(size: 12,weight:.black,design:.rounded)).lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(PopColor.ink)
            .frame(maxWidth:.infinity)
            .padding(.vertical,8)
            .background(selected ? PopColor.yellow : Color.white, in: Capsule())
            .overlay(Capsule().stroke(selected ? PopColor.yellow : Color(red:0.44,green:0.67,blue:0.96),lineWidth:2))
        }.buttonStyle(.plain)
    }
}

enum PopArtworkKind { case cards, genres, hero, logo }

/// Crops only *illustration assets* into UI pieces. Labels, cards, controls,
/// hit targets, navigation, video and manga pages are all genuine native views.
/// The bundled optional atlases can be replaced without changing UI code.
struct PopArtwork: View {
    var kind: PopArtworkKind
    var index: Int = 0
    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image = PopArtwork.image(kind:kind,index:index) {
                    Image(uiImage:image).resizable().scaledToFill()
                } else {
                    // Older installations retain the original in-app Rex atlas.
                    MVSprite(tile: fallbackIndex).scaledToFill()
                }
            }
            .frame(width:proxy.size.width,height:proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
    private var fallbackIndex: Int {
        switch kind {
        case .cards: return [0, 5, 3, 1, 2, 4, 6, 15][max(0,min(index,7))]
        case .genres: return [10,8,9,1,12,13][max(0,min(index,5))]
        case .hero, .logo: return 7
        }
    }
    private static let cardImages: [UIImage?] = makeTiles(named:"PopCardAtlas",columns:4,rows:2)
    private static let genreImages: [UIImage?] = makeTiles(named:"PopGenreAtlas",columns:2,rows:3)
    private static let heroImage = UIImage(named:"PopHero")
    private static let logoImage = UIImage(named:"PopLogo")
    private static func makeTiles(named name:String,columns:Int,rows:Int) -> [UIImage?] {
        guard let cg=UIImage(named:name)?.cgImage else {return Array(repeating:nil,count:columns*rows)}
        let w=cg.width/columns, h=cg.height/rows
        return (0..<(columns*rows)).map { i in
            guard let tile=cg.cropping(to:CGRect(x:(i%columns)*w,y:(i/columns)*h,width:w,height:h))
            else {return nil}
            return UIImage(cgImage:tile)
        }
    }
    private static func image(kind:PopArtworkKind,index:Int) -> UIImage? {
        switch kind {
        case .cards: return cardImages.indices.contains(index) ? cardImages[index] : nil
        case .genres: return genreImages.indices.contains(index) ? genreImages[index] : nil
        case .hero: return heroImage
        case .logo: return logoImage
        }
    }
}

struct PopBrandHeader: View {
    var onMenu: () -> Void
    var onHelp: () -> Void
    var onExport: () -> Void
    var body: some View {
        HStack(spacing: 7) {
            Button(action:onMenu) {
                Image(systemName:"line.3.horizontal").font(.system(size:20,weight:.heavy))
                    .frame(width:39,height:38)
            }.accessibilityLabel("メニュー")
                .background(PopColor.royal,in:RoundedRectangle(cornerRadius:12))
                .overlay(RoundedRectangle(cornerRadius:12).stroke(PopColor.edge,lineWidth:2))
            HStack(spacing:2) {
                PopArtwork(kind:.logo).frame(width:40,height:42)
                    .clipShape(RoundedRectangle(cornerRadius:7))
                VStack(alignment:.leading,spacing:-2) {
                    Text("ムビコマ")
                        .font(.system(size:25,weight:.black,design:.rounded))
                        .italic()
                        .foregroundStyle(PopColor.yellow)
                        .shadow(color:PopColor.ink,radius:1,x:2,y:2)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text("動画をマンガに変換！")
                        .font(.system(size:9,weight:.black)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
            }
            Spacer(minLength:0)
            Button(action:onHelp) {
                Image(systemName:"questionmark").font(.system(size:16,weight:.heavy))
                    .frame(width:32,height:33)
                    .background(PopColor.royal,in:Circle())
                    .overlay(Circle().stroke(PopColor.edge,lineWidth:2))
            }.accessibilityLabel("ヘルプ")
            Button(action:onExport) {
                Label("書き出し",systemImage:"square.and.arrow.up")
                    .font(.system(size:12,weight:.black,design:.rounded))
                    .foregroundStyle(PopColor.ink).lineLimit(1)
                    .padding(.horizontal,9).padding(.vertical,10)
                    .background(PopColor.yellow,in:Capsule())
                    .overlay(Capsule().stroke(.white,lineWidth:1.6))
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.horizontal,12).padding(.top,5).padding(.bottom,9)
        .background(PopColor.blue.opacity(0.25))
    }
}

enum PopStage: Int, CaseIterable { case editor = 0, styles = 1, review = 2 }

struct PopStepNavigation: View {
    @Binding var stage: PopStage
    var body: some View {
        HStack(spacing:3) {
            item(.editor,icon:"play.rectangle",text:"編集")
            Image(systemName:"chevron.right").font(.system(size:9,weight:.bold))
            item(.styles,icon:"paintbrush",text:"画風")
            Image(systemName:"chevron.right").font(.system(size:9,weight:.bold))
            item(.review,icon:"book",text:"漫画レビュー")
        }
        .foregroundStyle(.white)
        .padding(.horizontal,7).padding(.vertical,7)
        .background(LinearGradient(colors:[PopColor.navy,PopColor.royal],startPoint:.top,endPoint:.bottom),
                    in:Capsule())
        .overlay(Capsule().stroke(PopColor.cyan,lineWidth:2))
        .padding(.horizontal,9).padding(.vertical,6)
    }
    private func item(_ current: PopStage,icon:String,text:String)->some View {
        Button {stage=current} label: {
            HStack(spacing:3) {
                Image(systemName:icon).font(.system(size:13,weight:.semibold))
                Text(text).font(.system(size:11,weight:.bold,design:.rounded))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth:.infinity)
            .padding(.vertical,8)
            .background(stage==current ? PopColor.blue.opacity(0.9) : .clear,in:Capsule())
            .overlay(Capsule().stroke(stage==current ? PopColor.cyan : .clear,lineWidth:2))
        }.buttonStyle(.plain)
    }
}

struct PopIllustratedCard: View {
    var title: String
    var artIndex: Int
    var kind: PopArtworkKind = .cards
    var selected: Bool = false
    var body: some View {
        VStack(spacing:0) {
            PopArtwork(kind:kind,index:artIndex).aspectRatio(kind == .genres ? 1.62 : 1.12,contentMode:.fit)
                .clipShape(RoundedRectangle(cornerRadius:10))
                .overlay(alignment:.topTrailing) {
                    if selected {
                        Image(systemName:"checkmark.circle.fill")
                            .font(.system(size:24,weight:.heavy))
                            .foregroundStyle(PopColor.yellow)
                            .shadow(color:PopColor.navy,radius:1)
                            .padding(3)
                    }
                }
            Text(title).font(.system(size:13,weight:.black,design:.rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(PopColor.ink)
                .frame(maxWidth:.infinity).padding(.vertical,5)
                .background(.white,in:Capsule())
                .padding(.horizontal,4).padding(.bottom,4)
        }
        .background(PopColor.paper,in:RoundedRectangle(cornerRadius:13))
        .overlay(RoundedRectangle(cornerRadius:13)
                    .stroke(selected ? PopColor.yellow : PopColor.edge,lineWidth:selected ? 3 : 2))
        .shadow(color:selected ? PopColor.yellow.opacity(0.65) : PopColor.royal.opacity(0.2),
                radius:selected ? 7 : 3,y:2)
    }
}
