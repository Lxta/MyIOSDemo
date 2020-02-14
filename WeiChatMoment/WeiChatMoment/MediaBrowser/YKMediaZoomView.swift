//
//  YKImageZoomView.swift
//  WeiChatMoment
//
//  Created by lin kang on 2019/11/7.
//  Copyright © 2019 TW. All rights reserved.
//

import UIKit

struct  MediaType:OptionSet {
    public let rawValue:Int
    
    init(rawValue:Int) {
        self.rawValue = rawValue
    }
    
    static  let MediaTypeImage:MediaType = MediaType(rawValue: 1<<0)
    static let  MediaTypeVedio:MediaType = MediaType(rawValue: 1<<1)
    static let  MediaTypeNone:MediaType = MediaType(rawValue: 1<<2)

    static func findType(path:String) -> MediaType {
        let fileURL = URL(fileURLWithPath: path)
        let extention = fileURL.pathExtension.lowercased();
        let imageSuffix:Set<String> = ["png","jpg","jpeg","gif"];
        let vedioSuffix:Set<String> = ["avi", "rmvb","rm","asf" ,"divx", "mpg", "mpeg", "mpe", "wmv", "mp4", "mkv" ,"vob" ];
        if imageSuffix.contains(extention) {
            return MediaTypeImage;
        }else if vedioSuffix.contains(extention){
            return MediaTypeVedio;
        }
        
        return MediaTypeNone
    }
}

typealias ZoomerDidDismisClosure = ()->()
typealias ZoomerWillDismisClosure = ()->()

class YKMediaZoomView: UIView {
    //will remove the browser
     var zoomerWillDismiss:ZoomerWillDismisClosure?
    //did remove the browser
    var zoomerDidDismiss:ZoomerDidDismisClosure?
    // current index
    var index:Int = 0
    //首次出现展开动画
    var animateAtFirstShowOut = false

    fileprivate let scrollView:UIScrollView = UIScrollView()
    fileprivate var zoomImageView:YKTouchImageView = YKTouchImageView(frame: CGRect.zero)
    //用来手势滑动计算位置
    fileprivate var zoomedFrame:CGRect?
    
    fileprivate var preGuestureTouch:CGPoint?
    fileprivate var panGuestureSouldReceiveTouch = false
    fileprivate var mediaOb:YKMediaObject?
    fileprivate var isZooming = false;
    
    var mediaType:MediaType?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
                
        //finish load image
        zoomImageView.imageComplete = { [weak self] (image) in
            self?.scrollView.zoomScale = 1
            self?.scrollView.maximumZoomScale = 1
            self?.scrollView.minimumZoomScale = 1
            self?.scrollView.contentSize = CGSize.zero
            self?.scrollView.contentSize = image.size;
            self?.zoomImageView.frame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
                let widhtScale = (self?.bounds.size.width ?? 0)/image.size.width
                let hegithScale = (self?.bounds.size.height ?? 0)/image.size.height
                var miniScale = min(widhtScale, hegithScale)
                let maxScale = 1.0
                //very long height image
                if widhtScale / hegithScale > 3  && hegithScale < 1 && widhtScale < 1 {
                    miniScale = widhtScale;
                }
            
                // for video can ignore at this moment
                if self?.mediaType == MediaType.MediaTypeVedio {
                    //这个很重要，图片大于屏幕时才设置，否则会使得整个zoom的计算方式不一样，会产生bug
                    if miniScale < 1{
                        miniScale = min(widhtScale, hegithScale)
                    }else{
                        miniScale = 1
                    }
                }else{
                    self?.scrollView.panGestureRecognizer.isEnabled = true
                    self?.scrollView.pinchGestureRecognizer?.isEnabled = true
                }
                self?.scrollView.minimumZoomScale = miniScale
                self?.scrollView.maximumZoomScale = CGFloat(maxScale)
                self?.scrollView.zoomScale = miniScale
                self?.scrollView.addSubview(self!.zoomImageView)
                
                self?.zoomedFrame = self?.zoomImageView.frame;
                self?.setNeedsLayout()
                self?.layoutIfNeeded()
                
                self?.zoomedFrame = self?.zoomImageView.frame;
        }
        
        //视频加载完成
        zoomImageView.vedioComplete = {
            [weak self] in
            DispatchQueue.main.async {
                  //禁止视频缩放
                self?.scrollView.panGestureRecognizer.isEnabled = false
                self?.scrollView.pinchGestureRecognizer?.isEnabled = false
            }
        }
        
        self.backgroundColor = UIColor.black
        self.addSubview(scrollView)
        
        let panGuesture:UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panning(_:)));
        panGuesture.delegate = self
        self.addGestureRecognizer(panGuesture)
        
        let singleTapGuesture:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapping(_:)));
        singleTapGuesture.numberOfTapsRequired = 1
        self.addGestureRecognizer(singleTapGuesture)
        
        let douleTapGuesture:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTapping(_:)))
        douleTapGuesture.numberOfTapsRequired = 2
        self.addGestureRecognizer(douleTapGuesture)
        singleTapGuesture.require(toFail: douleTapGuesture)
        
        let longTapGuesture = UILongPressGestureRecognizer(target: self, action: #selector(longTapping(_:)))
        self.addGestureRecognizer(longTapGuesture)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //mark: -  手势
    @objc func panning(_ sender:UIPanGestureRecognizer)  {
        
        if sender.state == .began {
            
        }
        
        if sender.state == .changed  && zoomedFrame != nil{
            let translation = sender.translation(in: self);
            let movingDistance = sqrt(translation.x*translation.x + translation.y*translation.y)
            let movingCenter = CGPoint(x: zoomedFrame!.midX + translation.x, y: zoomedFrame!.midY + translation.y)
            let ratio = movingDistance/300.0

            zoomImageView.center = movingCenter
            var imageFrame = zoomImageView.frame
            var sizeRatio = 1-ratio
            if sizeRatio < 0.6{
                sizeRatio = 0.6
            }
            imageFrame.size.width = zoomedFrame!.size.width * (sizeRatio)
            imageFrame.size.height = zoomedFrame!.size.height * (sizeRatio)
            zoomImageView.frame = imageFrame;
            self.backgroundColor = UIColor.black.withAlphaComponent((1-ratio*3))
            self.superview?.backgroundColor = UIColor.black.withAlphaComponent((1-ratio*3))
        }
        
        if sender.state == .ended  && zoomedFrame != nil{
            if zoomImageView.center.y - zoomedFrame!.midY > 50{
                removePage()
            }else{
                UIView.animate(withDuration: 0.3, animations: {
                    self.zoomImageView.frame = self.zoomedFrame!
                    self.backgroundColor = UIColor.black.withAlphaComponent((1))
                    self.superview?.backgroundColor = UIColor.black.withAlphaComponent((1))
                })
            }
            
            preGuestureTouch = nil;
        }
        
    }
    
    @objc func tapping(_ gusture:UITapGestureRecognizer){
        removePage()
    }
    
    @objc func doubleTapping(_ guesture:UITapGestureRecognizer){
        if mediaType == MediaType.MediaTypeVedio {
            return;
        }
        if scrollView.zoomScale != 1 {
            scrollView.setZoomScale(1, animated: true)
        }else{
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        }
    }
    
    @objc func longTapping(_ guesture:UITapGestureRecognizer)  {
        
    }
    
    //MARK:- 功能方法
    fileprivate func removePage()  {
        //移除界面
        if self.zoomerWillDismiss != nil{
            self.zoomerWillDismiss!()
        }
        self.backgroundColor = UIColor.clear
        self.superview?.backgroundColor = UIColor.clear
        self.zoomImageView.hideVedio()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            if let fromView = self.mediaOb?.fromView {
                let windowRect = fromView.convert(fromView.bounds, to: UIApplication.shared.windows[0])
                let fromRect =  UIApplication.shared.windows[0].convert(windowRect, to: self)
                self.zoomImageView.frame = fromRect;
            }else{
                self.zoomImageView.alpha = 0
            }
        }, completion: { [weak self] (finish) in
            self?.zoomImageView.clear()
            if self?.zoomerDidDismiss != nil{
                self?.zoomerDidDismiss!()
            }
        })
    }
    
    //MARK: - 设置显示视频图片等
    func setItem(object:YKMediaObject)  {
        self.mediaOb = object;
        self.scrollView.zoomScale = 1
        self.scrollView.maximumZoomScale = 1
        self.scrollView.minimumZoomScale = 1
        self.scrollView.contentSize = CGSize.zero
        self.zoomImageView.alpha = 1
        self.index = object.index
        //设置缩略图
        if let thumImage = object.thumbImage{
            self.zoomImageView.image = object.thumbImage
            self.zoomImageView.imageComplete?(thumImage)
        }
        
        //首次出现时有动画，导致图片为第一次大小，所以设置延时
        var dealyTime = 0.0
        if animateAtFirstShowOut {
            dealyTime = 0.3
        }
        
        if let path = object.path ,object.vedioPath == nil{
            //图片
            mediaType = MediaType.findType(path: object.path ?? "")
            if mediaType == MediaType.MediaTypeNone{
                mediaType = MediaType.MediaTypeImage
            }
            if mediaType == MediaType.MediaTypeImage {
    
                DispatchQueue.main.asyncAfter(deadline: .now() + dealyTime, execute: {
                    self.zoomImageView.setImage(path: path)
                })
            }
        }else if object.vedioPath != nil{
            //视频
            mediaType = MediaType.findType(path: object.vedioPath ?? "")
             if mediaType == MediaType.MediaTypeVedio{
                DispatchQueue.main.asyncAfter(deadline: .now() + dealyTime, execute: {
                })
                //背景图为空时，默认为全屏幕大小
                if (object.path ?? "").isEmpty || object.isFullScreen{
                    zoomImageView.frame = self.bounds
                    scrollView.addSubview(zoomImageView)
                }
            }
        }else if let asset = object.imageAsset{
            //相册资源
            if asset.mediaType == .image{
                mediaType = MediaType.MediaTypeImage
                DispatchQueue.main.asyncAfter(deadline: .now() + dealyTime, execute: {
                    self.zoomImageView.setImage(asset: asset)
                })
            }
        }
        
    }
    
    func clearContent()  {
        zoomImageView.clear()
        zoomImageView.removeFromSuperview()
        zoomedFrame = nil
        self.scrollView.contentSize = CGSize.zero
        self.removeFromSuperview()
    }
    
   fileprivate func centerImage()  {
        var imageFrame = self.zoomImageView.frame
        if imageFrame.size.width < self.bounds.size.width {
            imageFrame.origin.x = (self.bounds.size.width - imageFrame.size.width)/2
        }else{
            imageFrame.origin.x = 0
        }
        
        if imageFrame.size.height < self.bounds.size.height {
            imageFrame.origin.y = (self.bounds.size.height - imageFrame.size.height)/2
        }else{
            imageFrame.origin.y = 0
        }
        zoomImageView.frame = imageFrame;
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.scrollView.frame = self.bounds
        
        if animateAtFirstShowOut,  let fromView = self.mediaOb?.fromView,self.zoomedFrame != nil{
            //首次出现是否显示展开动画
            self.animateAtFirstShowOut = false;
            let fromRect = fromView.convert(fromView.bounds, to: self.scrollView)
            self.zoomImageView.frame = fromRect;
            UIView.animate(withDuration: 0.3, animations: {
                self.zoomImageView.frame = self.zoomedFrame!
                self.centerImage()
            }, completion: { (finish) in
            })
        }else{
            centerImage()
        }
    }
}

//MARK:- UIScrollViewDelegate

extension YKMediaZoomView:UIScrollViewDelegate{
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
//        if mediaType != nil,mediaType! == .MediaTypeImage {
            self.setNeedsLayout()
            self.layoutIfNeeded()
//        }
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        isZooming = true
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        zoomedFrame = self.zoomImageView.frame;
        isZooming = false
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return zoomImageView
    }
}

//MARK:- 手势代理
extension YKMediaZoomView:UIGestureRecognizerDelegate{
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool{

        if (gestureRecognizer == self.scrollView.panGestureRecognizer || gestureRecognizer == self.scrollView.pinchGestureRecognizer) {
            return false
        }
        return true
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
     
        if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let translation = gestureRecognizer.translation(in: self)
            if translation.y > 0 && !isZooming{
                return true
            }else{
                return false
            }
        }
        
        return true
    }
    
}
