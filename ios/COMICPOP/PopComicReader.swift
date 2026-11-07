import SwiftUI

/// A real manga reader: every SavedWork.files entry is one readable page.
/// Never silently drops missing pages (which previously looked like "page 2" vanished).
struct PopComicReader: View {
    @ObservedObject var store: StudioStore
    let work: SavedWork
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var continuous = false
    @State private var zoomedPage: Int?
    @State private var pdfURL: URL?
    @State private var showShare = false

    private var total: Int {work.files.count}
    private func image(at index: Int) -> UIImage? {
        guard work.files.indices.contains(index),
              let url=store.existingWorkURL(work.files[index]) else {return nil}
        return UIImage(contentsOfFile:url.path)
    }
    private var currentFile: URL? {
        guard work.files.indices.contains(page) else {return nil}
        return store.existingWorkURL(work.files[page])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing:0) {
                HStack(spacing:8) {
                    Label("\(total)ページ / \(work.sceneCount)コマ",systemImage:"book.closed.fill")
                        .font(.system(size:12,weight:.black,design:.rounded))
                    Spacer()
                    Button {
                        continuous.toggle()
                    } label: {
                        Label(continuous ? "1ページずつ" : "縦に読む",
                              systemImage:continuous ? "rectangle" : "rectangle.stack")
                            .font(.system(size:11,weight:.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(PopColor.royal)
                }
                .foregroundStyle(PopColor.ink)
                .padding(.horizontal,14).padding(.vertical,8)
                .background(PopColor.paper)

                if total == 0 {
                    ContentUnavailableView("ページがありません",
                                           systemImage:"exclamationmark.triangle",
                                           description:Text("作品ファイルを確認してください。"))
                } else if continuous {
                    ScrollViewReader { scroll in
                        ScrollView(.vertical,showsIndicators:true) {
                            LazyVStack(spacing:14) {
                                ForEach(0..<total,id:\.self) { index in
                                    VStack(alignment:.leading,spacing:5) {
                                        Text("\(index+1) / \(total) ページ")
                                            .font(.system(size:12,weight:.black,design:.monospaced))
                                            .foregroundStyle(.white)
                                        pageImage(index)
                                            .frame(maxWidth:.infinity)
                                    }
                                    .id(index)
                                    .padding(.horizontal,10)
                                    .onTapGesture {page=index}
                                }
                            }
                            .padding(.vertical,10)
                        }
                        .onChange(of:continuous) { _, now in
                            if now {scroll.scrollTo(page,anchor:.top)}
                        }
                    }
                } else {
                    GeometryReader { geometry in
                        TabView(selection:$page) {
                            ForEach(0..<total,id:\.self) { index in
                                VStack(spacing:6) {
                                    pageImage(index)
                                        .frame(maxWidth:.infinity,maxHeight:.infinity)
                                    Text("ページ \(index+1) / \(total)")
                                        .font(.system(size:12,weight:.heavy,design:.rounded))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal,10).padding(.vertical,7)
                                .frame(width:geometry.size.width,height:geometry.size.height)
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode:.never))
                    }
                }

                VStack(spacing:8) {
                    HStack(spacing:7) {
                        Button {page=max(0,page-1)} label:{
                            Label("前",systemImage:"chevron.left")
                        }.disabled(page==0)
                        Spacer()
                        Text("\(min(page+1,total)) / \(total)")
                            .font(.system(size:15,weight:.black,design:.monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {page=min(total-1,page+1)} label:{
                            Label("次",systemImage:"chevron.right")
                        }.disabled(total==0 || page==total-1)
                    }
                    .font(.system(size:13,weight:.heavy,design:.rounded))
                    .buttonStyle(.borderedProminent)
                    .tint(PopColor.blue)

                    ScrollViewReader { selection in
                        ScrollView(.horizontal,showsIndicators:false) {
                            HStack(spacing:8) {
                                ForEach(0..<total,id:\.self) { index in
                                    Button {page=index} label:{
                                        VStack(spacing:3) {
                                            if let img=image(at:index) {
                                                Image(uiImage:img)
                                                    .resizable().scaledToFit()
                                                    .frame(width:56,height:78)
                                                    .background(.white)
                                            } else {
                                                Image(systemName:"exclamationmark.triangle")
                                                    .frame(width:56,height:78)
                                                    .background(.white)
                                            }
                                            Text("\(index+1)")
                                                .font(.system(size:11,weight:.black,design:.monospaced))
                                                .foregroundStyle(.white)
                                        }
                                        .padding(4)
                                        .overlay(RoundedRectangle(cornerRadius:7)
                                            .stroke(index==page ? PopColor.yellow : PopColor.edge,
                                                    lineWidth:index==page ? 3 : 1))
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }
                            }
                            .padding(.horizontal,11)
                        }
                        .frame(height:110)
                        .onChange(of:page) { _,next in
                            withAnimation(.easeOut(duration:0.2)) {
                                selection.scrollTo(next,anchor:.center)
                            }
                        }
                    }
                }
                .padding(10)
                .background(PopColor.navy.opacity(0.9))
            }
            .background(PopBackground())
            .navigationTitle(work.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarLeading) {
                    Button("閉じる",systemImage:"xmark") {dismiss()}
                }
                ToolbarItemGroup(placement:.topBarTrailing) {
                    if let url=currentFile {
                        ShareLink(item:url) {Image(systemName:"square.and.arrow.up")}
                    }
                    Button {
                        pdfURL=store.exportPDF(work)
                        showShare=pdfURL != nil
                    } label:{Image(systemName:"doc.richtext")}
                    .accessibilityLabel("全ページをPDFで共有")
                }
            }
        }
        .sheet(isPresented:$showShare) {
            if let pdfURL {PopFileShareSheet(files:[pdfURL])}
        }
        .sheet(item:Binding<ZoomItem?>(
            get:{zoomedPage.map{ZoomItem(index:$0)}},
            set:{zoomedPage=$0?.index}
        )) { item in
            NavigationStack {
                ScrollView([.vertical,.horizontal]) {
                    if let source=image(at:item.index) {
                        PopZoomImage(source:source)
                            .frame(minHeight:350)
                    }
                }
                .background(Color.black)
                .navigationTitle("\(item.index+1)ページ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.topBarTrailing) {
                        Button("閉じる") {zoomedPage=nil}
                    }
                }
            }
        }
        .accessibilityIdentifier("popComicReaderAllPages")
    }

    @ViewBuilder private func pageImage(_ index:Int)->some View {
        if let source=image(at:index) {
            Button {zoomedPage=index} label:{
                Image(uiImage:source)
                    .resizable().scaledToFit()
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(PopColor.ink,lineWidth:1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(index+1)ページを拡大して読む")
        } else {
            VStack(spacing:8) {
                Image(systemName:"exclamationmark.triangle.fill")
                    .font(.system(size:30))
                Text("\(index+1)ページの画像が見つかりません")
                    .font(.headline)
                Text("他のページは残っています。作品データを確認してください。")
                    .font(.caption).multilineTextAlignment(.center)
            }
            .foregroundStyle(PopColor.ink)
            .frame(maxWidth:.infinity,minHeight:250)
            .background(PopColor.paper)
        }
    }
}
private struct ZoomItem: Identifiable {
    let index:Int
    var id:Int {index}
}
/// Allows enlargement of the saved 900px page without changing its content.
private struct PopZoomImage: View {
    let source:UIImage
    @State private var magnification:CGFloat = 1.0
    var body:some View {
        Image(uiImage:source)
            .resizable().scaledToFit()
            .scaleEffect(magnification)
            .gesture(MagnificationGesture()
                .onChanged{magnification=max(1,min(4,$0))}
                .onEnded{_ in if magnification<1.05 {magnification=1}})
            .padding(10)
    }
}
