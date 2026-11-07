import UIKit

/// A single temporary overview image for the whole movie's selected scenes.
/// The cloud story model sees the entire sequence at once rather than
/// receiving only unrelated English classification labels.
@MainActor enum MangaSceneContactSheet {
    /// A storyboard is action-based, not just a gallery of still images.
    /// Each row shows BEFORE / USER CARD / AFTER around one selected scene.
    static func motionJPEG(from triples:[[UIImage]]) -> Data? {
        guard !triples.isEmpty,triples.allSatisfy({$0.count==3}) else {return nil}
        let cell=CGSize(width:240,height:158)
        let sheetSize=CGSize(width:cell.width*3,
                             height:cell.height*CGFloat(triples.count))
        let format=UIGraphicsImageRendererFormat()
        format.scale=1
        format.opaque=true
        let sheet=UIGraphicsImageRenderer(size:sheetSize,format:format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin:.zero,size:sheetSize))
            for (row,scene) in triples.enumerated() {
                for (column,photo) in scene.enumerated() {
                    let box=CGRect(x:CGFloat(column)*cell.width+2,
                                   y:CGFloat(row)*cell.height+2,
                                   width:cell.width-4,height:cell.height-4)
                    let factor=max(box.width/max(photo.size.width,1),
                                   box.height/max(photo.size.height,1))
                    let scaled=CGRect(x:box.midX-photo.size.width*factor/2,
                                      y:box.midY-photo.size.height*factor/2,
                                      width:photo.size.width*factor,
                                      height:photo.size.height*factor)
                    let graphics=UIGraphicsGetCurrentContext()
                    graphics?.saveGState()
                    graphics?.clip(to:box)
                    photo.draw(in:scaled)
                    graphics?.restoreGState()
                    let tag=["BEFORE","CARD","AFTER"][column]
                    let label="S\(row+1) \(tag)"
                    let badge=CGRect(x:box.minX+4,y:box.minY+4,
                                     width:120,height:25)
                    UIColor.black.withAlphaComponent(0.8).setFill()
                    UIRectFill(badge)
                    (label as NSString).draw(
                        in:badge.insetBy(dx:5,dy:2),
                        withAttributes:[.font:UIFont.boldSystemFont(ofSize:14),
                                        .foregroundColor:UIColor.white]
                    )
                }
            }
        }
        return sheet.jpegData(compressionQuality:0.68)
    }

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
