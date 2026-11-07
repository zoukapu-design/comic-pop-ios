import UIKit

struct ImageDifference {
    static func distance(_ a:UIImage,_ b:UIImage)->Double {
        func grayscale(_ input:UIImage)->[UInt8]? {
            let width=16,height=16
            var pixels=[UInt8](repeating:0,count:width*height)
            let space=CGColorSpaceCreateDeviceGray()
            guard let cg=input.cgImage else{return nil}
            let drawn=pixels.withUnsafeMutableBytes { buffer -> Bool in
                guard let ctx=CGContext(data:buffer.baseAddress,width:width,height:height,
                    bitsPerComponent:8,bytesPerRow:width,space:space,
                    bitmapInfo:CGImageAlphaInfo.none.rawValue) else {return false}
                ctx.draw(cg,in:CGRect(x:0,y:0,width:width,height:height))
                return true
            }
            return drawn ? pixels : nil
        }
        guard let one=grayscale(a),let two=grayscale(b) else{return 1}
        let total=zip(one,two).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}
        return total/Double(one.count*255)
    }
}

/// Always renders valid Japanese text using native iOS fonts OUTSIDE the
/// image model. This avoids the illegible/pseudo-Japanese glyphs emitted by
/// diffusion models and makes 5+ cards become real multi-page manga.
enum ComicRenderer {
    static func page(panels:[PreviewPanel],title:String,pageNumber:Int,total:Int)->UIImage {
        let size=CGSize(width:900,height:1270)
        let format=UIGraphicsImageRendererFormat()
        format.scale=1
        format.opaque=true
        return UIGraphicsImageRenderer(size:size,format:format).image { context in
            let ctx=context.cgContext
            UIColor(red:1,green:0.991,blue:0.953,alpha:1).setFill()
            ctx.fill(CGRect(origin:.zero,size:size))
            UIColor(red:0.05,green:0.10,blue:0.24,alpha:1).setFill()
            ctx.fill(CGRect(x:0,y:0,width:900,height:82))
            (title as NSString).draw(in:CGRect(x:30,y:19,width:715,height:48),
                withAttributes:[.font:UIFont.boldSystemFont(ofSize:30),
                                .foregroundColor:UIColor.systemYellow])
            ("\(pageNumber) / \(total)" as NSString).draw(
                in:CGRect(x:765,y:34,width:115,height:30),
                withAttributes:[.font:UIFont.boldSystemFont(ofSize:18),
                                .foregroundColor:UIColor.white])

            let slots:[CGRect]
            switch panels.count {
            case 1:
                slots=[CGRect(x:26,y:106,width:848,height:1085)]
            case 2:
                slots=[CGRect(x:26,y:106,width:848,height:527),
                       CGRect(x:26,y:648,width:848,height:543)]
            case 3:
                slots=[CGRect(x:26,y:106,width:848,height:542),
                       CGRect(x:26,y:663,width:417,height:528),
                       CGRect(x:457,y:663,width:417,height:528)]
            default:
                slots=[CGRect(x:26,y:106,width:848,height:429),
                       CGRect(x:26,y:550,width:417,height:328),
                       CGRect(x:457,y:550,width:417,height:328),
                       CGRect(x:26,y:893,width:848,height:298)]
            }
            for (index,panel) in panels.enumerated() {
                guard slots.indices.contains(index) else {continue}
                let slot=slots[index]
                ctx.saveGState()
                ctx.clip(to:slot)
                UIColor(white:0.94,alpha:1).setFill()
                ctx.fill(slot)
                let image=panel.drawing
                let width=max(1,image.size.width),height=max(1,image.size.height)
                // Crops like a real manga panel rather than floating a small
                // photograph in the middle of a large empty rectangle.
                let factor=max(slot.width/width,slot.height/height)
                let frame=CGRect(x:slot.midX-width*factor/2,y:slot.midY-height*factor/2,
                                 width:width*factor,height:height*factor)
                image.draw(in:frame)
                ctx.restoreGState()
                ctx.setStrokeColor(UIColor.black.cgColor)
                ctx.setLineWidth(6)
                ctx.stroke(slot)

                // Editorial beat chip remains separate from the narrative.
                let chip=CGRect(x:slot.minX+11,y:slot.minY+10,
                                width:min(slot.width-22,max(155,CGFloat(panel.cardTitle.count)*16+55)),height:30)
                let shape=UIBezierPath(roundedRect:chip,cornerRadius:7)
                UIColor(red:1,green:0.86,blue:0.1,alpha:1).setFill()
                shape.fill()
                ("\((pageNumber-1)*4+index+1) · \(panel.cardTitle)" as NSString)
                    .draw(in:chip.insetBy(dx:7,dy:4),withAttributes:[
                        .font:UIFont.boldSystemFont(ofSize:15),
                        .foregroundColor:UIColor.black
                    ])
                if !panel.caption.isEmpty {
                    let capHeight:CGFloat = slot.height < 340 ? 60 : 68
                    let captionRect=CGRect(x:slot.minX+12,y:slot.minY+45,
                        width:slot.width-24,height:capHeight)
                    UIColor(white:0.02,alpha:0.88).setFill()
                    UIBezierPath(roundedRect:captionRect,cornerRadius:9).fill()
                    let font=UIFont.boldSystemFont(ofSize:slot.width<500 ? 20 : 24)
                    (panel.caption as NSString).draw(
                        with:captionRect.insetBy(dx:12,dy:7),
                        options:[.usesLineFragmentOrigin,.truncatesLastVisibleLine],
                        attributes:[.font:font,.foregroundColor:UIColor.white],context:nil)
                }
                if !panel.dialogue.isEmpty {
                    let bubbleWidth=min(slot.width-25,max(220,slot.width*0.56))
                    let bubbleHeight:CGFloat=slot.height<340 ? 83 : 106
                    let bubble=CGRect(x:slot.maxX-bubbleWidth-12,
                        y:slot.maxY-bubbleHeight-13,width:bubbleWidth,height:bubbleHeight)
                    let contour=UIBezierPath(roundedRect:bubble,cornerRadius:28)
                    UIColor.white.setFill()
                    contour.fill()
                    UIColor.black.setStroke()
                    contour.lineWidth=3
                    contour.stroke()
                    let tail=UIBezierPath()
                    tail.move(to:CGPoint(x:bubble.minX+52,y:bubble.maxY-1))
                    tail.addLine(to:CGPoint(x:bubble.minX+35,y:slot.maxY-2))
                    tail.addLine(to:CGPoint(x:bubble.minX+82,y:bubble.maxY-2))
                    tail.close()
                    UIColor.white.setFill();tail.fill()
                    let textRect=bubble.insetBy(dx:15,dy:12)
                    let para=NSMutableParagraphStyle()
                    para.alignment = .center
                    let font=UIFont.boldSystemFont(ofSize:slot.width<500 ? 21 : 25)
                    (panel.dialogue as NSString).draw(
                        with:textRect,
                        options:[.usesLineFragmentOrigin,.truncatesLastVisibleLine],
                        attributes:[.font:font,.foregroundColor:UIColor.black,
                                    .paragraphStyle:para],context:nil)
                }
                if panel.warning != nil {
                    UIColor.systemRed.setFill()
                    let warning=CGRect(x:slot.minX+12,y:slot.maxY-39,
                        width:min(slot.width-24,280),height:28)
                    ctx.fill(warning)
                    ("このコマの構成を確認" as NSString).draw(
                        in:warning.insetBy(dx:6,dy:4),
                        withAttributes:[.font:UIFont.boldSystemFont(ofSize:14),
                                        .foregroundColor:UIColor.white])
                }
            }
            ("ムビコマ ｜ 動画とカードから物語を再構成した創作漫画" as NSString).draw(
                in:CGRect(x:28,y:1228,width:840,height:24),
                withAttributes:[.font:UIFont.systemFont(ofSize:16),
                                .foregroundColor:UIColor.darkGray])
        }
    }
}