import UIKit

/// A single temporary overview image for the whole movie's selected scenes.
/// The cloud story model sees the entire sequence at once rather than
/// receiving only unrelated English classification labels.
@MainActor enum MangaSceneContactSheet {
    static func jpeg(from images:[UIImage]) -> Data? {
        guard !images.isEmpty else {return nil}
        let columns=images.count<=4 ? 2 : 3
        let rows=(images.count+columns-1)/columns
        let cell=CGSize(width:290,height:204)
        let size=CGSize(width:CGFloat(columns)*cell.width,
                        height:CGFloat(rows)*cell.height)
        let format=UIGraphicsImageRendererFormat()
        format.scale=1
        format.opaque=true
        let image=UIGraphicsImageRenderer(size:size,format:format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin:.zero,size:size))
            for (index,frame) in images.enumerated() {
                let col=index%columns
                let row=index/columns
                let base=CGRect(x:CGFloat(col)*cell.width+3,
                                y:CGFloat(row)*cell.height+3,
                                width:cell.width-6,height:cell.height-6)
                UIColor.white.setFill()
                UIRectFill(base)
                let factor=max(base.width/max(frame.size.width,1),
                               base.height/max(frame.size.height,1))
                let rect=CGRect(x:base.midX-frame.size.width*factor/2,
                                y:base.midY-frame.size.height*factor/2,
                                width:frame.size.width*factor,
                                height:frame.size.height*factor)
                let ctx=UIGraphicsGetCurrentContext()
                ctx?.saveGState()
                ctx?.clip(to:base)
                frame.draw(in:rect)
                ctx?.restoreGState()
                let badge=CGRect(x:base.minX+6,y:base.minY+6,width:86,height:27)
                UIColor.black.withAlphaComponent(0.84).setFill()
                UIRectFill(badge)
                ("Scene \(index+1)" as NSString).draw(
                    in:badge.insetBy(dx:5,dy:3),
                    withAttributes:[.font:UIFont.boldSystemFont(ofSize:15),
                                    .foregroundColor:UIColor.white]
                )
            }
        }
        return image.jpegData(compressionQuality:0.78)
    }
}
