import UIKit

struct ImageDifference {
    static func distance(_ a:UIImage,_ b:UIImage)->Double {
        func grayscale(_ input:UIImage)->[UInt8]? {
            let width=16,height=16
            var pixels=[UInt8](repeating:0,count:width*height)
            let space=CGColorSpaceCreateDeviceGray()
            guard let cg=input.cgImage else{return nil}
            let drawn=pixels.withUnsafeMutableBytes { buffer -> Bool in
                guard let ctx=CGContext(data:buffer.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width,space:space,bitmapInfo:CGImageAlphaInfo.none.rawValue) else {return false}
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

enum ComicRenderer {
    static func page(panels:[PreviewPanel],title:String,pageNumber:Int,total:Int)->UIImage {
        let size=CGSize(width:900,height:1270)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        return UIGraphicsImageRenderer(size:size,format:format).image{context in
            let ctx=context.cgContext
            UIColor(red:1,green:0.991,blue:0.953,alpha:1).setFill();ctx.fill(CGRect(origin:.zero,size:size))
            UIColor(red:0.095,green:0.13,blue:0.23,alpha:1).setFill();ctx.fill(CGRect(x:0,y:0,width:900,height:86))
            (title as NSString).draw(in:CGRect(x:30,y:25,width:710,height:42),withAttributes:[.font:UIFont.boldSystemFont(ofSize:30),.foregroundColor:UIColor.systemYellow])
            ("P \(pageNumber)/\(total)" as NSString).draw(at:CGPoint(x:765,y:36),withAttributes:[.font:UIFont.boldSystemFont(ofSize:17),.foregroundColor:UIColor.white])
            let slots:[CGRect]
            switch panels.count {
            case 1:slots=[CGRect(x:26,y:108,width:848,height:1090)]
            case 2:slots=[CGRect(x:26,y:108,width:848,height:525),CGRect(x:26,y:648,width:848,height:550)]
            case 3:slots=[CGRect(x:26,y:108,width:848,height:545),CGRect(x:26,y:668,width:418,height:530),CGRect(x:457,y:668,width:417,height:530)]
            default:slots=[CGRect(x:26,y:108,width:848,height:435),CGRect(x:26,y:558,width:418,height:325),CGRect(x:457,y:558,width:417,height:325),CGRect(x:26,y:898,width:848,height:300)]
            }
            for (i,panel) in panels.enumerated(){
                let slot=slots[i];ctx.saveGState();ctx.addRect(slot);ctx.clip()
                UIColor(white:0.96,alpha:1).setFill();ctx.fill(slot)
                let image=panel.drawing;let w=image.size.width,h=image.size.height
                let scale=min(slot.width/max(w,1),slot.height/max(h,1))
                let fit=CGRect(x:slot.midX-w*scale/2,y:slot.midY-h*scale/2,width:w*scale,height:h*scale)
                image.draw(in:fit);ctx.restoreGState()
                ctx.setStrokeColor(UIColor(red:0.09,green:0.12,blue:0.19,alpha:1).cgColor);ctx.setLineWidth(6);ctx.stroke(slot)
                let label="📍\(i+1) \(panel.cardTitle)" as NSString
                let width=min(slot.width-20,max(116,CGFloat(label.length*21+32)))
                UIColor.systemYellow.setFill();ctx.fill(CGRect(x:slot.minX+12,y:slot.minY+10,width:width,height:38))
                label.draw(at:CGPoint(x:slot.minX+23,y:slot.minY+18),withAttributes:[.font:UIFont.boldSystemFont(ofSize:17),.foregroundColor:UIColor.black])
                if panel.warning != nil {
                    UIColor.systemRed.setFill();ctx.fill(CGRect(x:slot.minX+10,y:slot.maxY-42,width:min(slot.width-20,290),height:33))
                    ("元場面との一致を確認" as NSString).draw(at:CGPoint(x:slot.minX+18,y:slot.maxY-37),withAttributes:[.font:UIFont.boldSystemFont(ofSize:15),.foregroundColor:UIColor.white])
                }
            }
            ("COMIC POP! / AI再描画・原動画との一致をご確認ください" as NSString).draw(at:CGPoint(x:30,y:1230),withAttributes:[.font:UIFont.systemFont(ofSize:15),.foregroundColor:UIColor.darkGray])
        }
    }
}
