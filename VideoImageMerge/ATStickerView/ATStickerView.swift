//
//  ATStickerView.swift
//  StickerMaker
//
//  Created by Appernaut on 08/02/20.
//  Copyright © 2020 Appernaut. All rights reserved.
//

import UIKit
import SDWebImage

enum ATStickerViewHandler:Int {
    case close = 0
    case rotate
    case flip
}

enum ATStickerViewPosition:Int {
    case topLeft = 0
    case topRight
    case bottomLeft
    case bottomRight
}

@inline(__always) func CGRectGetCenter(_ rect:CGRect) -> CGPoint {
    return CGPoint(x: rect.midX, y: rect.midY)
}

@inline(__always) func CGRectScale(_ rect:CGRect, wScale:CGFloat, hScale:CGFloat) -> CGRect {
    return CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width * wScale, height: rect.size.height * hScale)
}

@inline(__always) func CGAffineTransformGetAngle(_ t:CGAffineTransform) -> CGFloat {
    return atan2(t.b, t.a)
}

@inline(__always) func CGPointGetDistance(point1:CGPoint, point2:CGPoint) -> CGFloat {
    let fx = point2.x - point1.x
    let fy = point2.y - point1.y
    return sqrt(fx * fx + fy * fy)
}

protocol ATStickerViewDelegate: class {
    func didTapContentView(_ stickerView: ATStickerView?)
    func didTapDeleteControl(_ stickerView: ATStickerView?)
    func didTapFlipControl(_ stickerView: ATStickerView?)
}

class ATStickerView: UIView {
    // DEFINE
    let initialControlWidth: CGFloat = 25.0
    let initialControlHalfWidth: CGFloat = 12.5

    let initialMinScale: CGFloat = 0.5
    let initialMaxScale: CGFloat = 3.0
    
    /**
     *  Variables for moving view
     */
    private var beginningPoint = CGPoint.zero
    private var beginningCenter = CGPoint.zero
    
    /**
     *  Variables for rotating and resizing view
     */
    private var initialBounds: CGRect = .zero
    private var initialDistance: CGFloat = 0
    private var deltaAngle: CGFloat = 0

    /**
     *  Default value
     */
    private var defaultInset:NSInteger = 0
    private var defaultMinimumSize:NSInteger = 0
    
    private var _minimumSize:NSInteger = 0
    var minimumSize:NSInteger {
        set {
            _minimumSize = max(newValue, self.defaultMinimumSize)
        }
        get {
            return _minimumSize
        }
    }
    
    // properties
    var isHandlingControlsEnable: Bool = true {
        didSet {
            if isHandlingControlsEnable {
                setEnableClose(enabledDeleteControl)
                setEnableResize(enableResizeControl)
                setEnableFlip(enableFlipControl)
                enabledBorder = true
            } else {
                setEnableClose(false)
                setEnableResize(false)
                setEnableFlip(false)
                enabledBorder = false
            }
        }
    }
    
    var enabledDeleteControl: Bool = true {
        didSet {
            if self.isHandlingControlsEnable {
                setEnableClose(enabledDeleteControl)
            }
        }
    }
    
    var enableResizeControl: Bool = true {
        didSet {
            if self.isHandlingControlsEnable {
                setEnableResize(enableResizeControl)
            }
        }
    }
    
    var enableFlipControl: Bool = true {
        didSet {
            if self.isHandlingControlsEnable {
                setEnableFlip(enableFlipControl)
            }
        }
    }
    
    private var enabledBorder = true {
        didSet {
            if enabledBorder {
                contentView.layer.addSublayer(shapeLayer)
            } else {
                shapeLayer.removeFromSuperlayer()
            }
        }
    }
        
    var contentImage: UIImage!
    var contentURL: String?
    public weak var delegate: ATStickerViewDelegate?

    private var contentView: UIImageView!
    private lazy var deleteControl: UIImageView = {
        let deleteImgView = UIImageView(frame: CGRect(x: 0, y: 0, width: initialControlWidth, height: initialControlWidth))
        deleteImgView.image = UIImage(named: "ATStickerView.bundle/btn_delete.png")!
        deleteImgView.isUserInteractionEnabled = true
        deleteImgView.addGestureRecognizer(self.closeGesture)
        return deleteImgView
    }()
    
    private lazy var resizeControl: UIImageView = {
        let resizeImgView = UIImageView(frame: CGRect(x: 0, y: 0, width: initialControlWidth, height: initialControlWidth))
        resizeImgView.image = UIImage(named: "ATStickerView.bundle/btn_resize.png")!
        resizeImgView.isUserInteractionEnabled = true
        resizeImgView.addGestureRecognizer(self.rotateGesture)
        return resizeImgView
    }()
    
    private lazy var flipControl: UIImageView = {
        let flipImgView = UIImageView(frame: CGRect(x: 0, y: 0, width: initialControlWidth, height: initialControlWidth))
        flipImgView.image = UIImage(named: "ATStickerView.bundle/btn_flip.png")!
        flipImgView.isUserInteractionEnabled = true
        flipImgView.addGestureRecognizer(self.flipGesture)
        return flipImgView
    }()
    
    private lazy var shapeLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        let shapeRect = contentView.frame
        shapeLayer.bounds = shapeRect
        shapeLayer.position = CGPoint(x: contentView.frame.size.width / 2, y: contentView.frame.size.height / 2)
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 1.0
        shapeLayer.lineJoin = .round
        shapeLayer.allowsEdgeAntialiasing = true
        shapeLayer.lineDashPattern = [5, 3]

        let path = CGMutablePath()
        path.addRect(shapeRect, transform: .identity)
        shapeLayer.path = path
        return shapeLayer
    }()
    
    private lazy var moveGesture = {
        return UIPanGestureRecognizer(target: self, action: #selector(self.handleMoveGesture(_:)))
    }()
    
    private lazy var rotateGesture = {
        return UIPanGestureRecognizer(target: self, action: #selector(handleRotateGesture(_:)))
    }()
    
    private lazy var closeGesture = {
        return UITapGestureRecognizer(target: self, action: #selector(self.handleCloseGesture(_:)))
    }()
    
    private lazy var flipGesture = {
        return UITapGestureRecognizer(target: self, action: #selector(self.handleFlipGesture(_:)))
    }()
    
    private lazy var tapGesture = {
        return UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
    }()
        
    override var bounds: CGRect {
        didSet {
            if contentView.layer.sublayers?.contains(shapeLayer) ?? false {
                let shapeRect = contentView.frame
                shapeLayer.bounds = shapeRect
                shapeLayer.position = CGPoint(x: contentView.frame.size.width / 2, y: contentView.frame.size.height / 2)
                
                let path = CGMutablePath()
                path.addRect(shapeRect, transform: .identity)
                shapeLayer.path = path
                contentView.layoutIfNeeded()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init(contentFrame frame: CGRect, animatedImageURL: String?) {
        super.init(frame: CGRect(x: frame.origin.x - initialControlHalfWidth,
                                 y: frame.origin.y - initialControlHalfWidth,
                                 width: frame.size.width + initialControlWidth,
                                 height: frame.size.height + initialControlWidth))
        contentView = UIImageView(frame: CGRect(x: initialControlHalfWidth,
                                                y: initialControlHalfWidth,
                                                width: frame.size.width,
                                                height: frame.size.height))
        guard let urlString = animatedImageURL, let url = URL(string: urlString) else { return }
        contentURL = urlString

        contentView!.sd_setImage(with: url, placeholderImage: nil, options: [.progressiveLoad]) { image, error, cacheType, imageURL in
            self.contentImage = image
        }
        self.contentView.isUserInteractionEnabled = false
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.contentView.layer.allowsEdgeAntialiasing = true
        addSubview(contentView!)
        setupConfig()
    }


    func setupConfig() {
        self.defaultInset = 11
        self.defaultMinimumSize = 4 * self.defaultInset
        self.minimumSize = self.defaultMinimumSize
        
        isExclusiveTouch = true
        isUserInteractionEnabled = true
        contentView.isUserInteractionEnabled = true
        
        // Setup editing handlers
        self.setPosition(.topLeft, forHandler: .close)
        self.addSubview(self.deleteControl)
        self.setPosition(.bottomRight, forHandler: .rotate)
        self.addSubview(self.resizeControl)
        self.setPosition(.bottomLeft, forHandler: .flip)
        self.addSubview(self.flipControl)
        
        isHandlingControlsEnable = true
        enabledDeleteControl = true
        enableResizeControl = true
        enableFlipControl = true
        
        attachGestures()
    }

    func attachGestures() {
        self.contentView.addGestureRecognizer(self.tapGesture)
        self.contentView.addGestureRecognizer(self.moveGesture)
    }

    // MARK: - Handle Gestures
    @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        superview?.bringSubviewToFront(self)
        if let delegate = delegate {
            delegate.didTapContentView(self)
        }
    }
    
    @objc
    func handleCloseGesture(_ recognizer: UITapGestureRecognizer) {
        if let delegate = self.delegate {
            delegate.didTapDeleteControl(self)
        }
        self.removeFromSuperview()
    }
    
    @objc
    func handleFlipGesture(_ recognizer: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.3) {
            self.contentView.transform = self.contentView.transform.scaledBy(x: -1, y: 1)
        }
    }
    
    @objc func handleMoveGesture(_ gesture: UIPanGestureRecognizer) {
        let touchLocation = gesture.location(in: self.superview)
        switch gesture.state {
        case .began:
            self.beginningPoint = touchLocation
            self.beginningCenter = self.center
        case .changed:
            self.center = CGPoint(x: self.beginningCenter.x + (touchLocation.x - self.beginningPoint.x), y: self.beginningCenter.y + (touchLocation.y - self.beginningPoint.y))
        case .ended:
            self.center = CGPoint(x: self.beginningCenter.x + (touchLocation.x - self.beginningPoint.x), y: self.beginningCenter.y + (touchLocation.y - self.beginningPoint.y))
        default:
            break
        }
    }
    
    @objc
    func handleRotateGesture(_ recognizer: UIPanGestureRecognizer) {
        let touchLocation = recognizer.location(in: self.superview)
        let center = self.center
        
        switch recognizer.state {
        case .began:
            self.deltaAngle = CGFloat(atan2f(Float(touchLocation.y - center.y), Float(touchLocation.x - center.x))) - CGAffineTransformGetAngle(self.transform)
            self.initialBounds = self.bounds
            self.initialDistance = CGPointGetDistance(point1: center, point2: touchLocation)
        case .changed:
            let angle = atan2f(Float(touchLocation.y - center.y), Float(touchLocation.x - center.x))
            let angleDiff = Float(self.deltaAngle) - angle
            self.transform = CGAffineTransform(rotationAngle: CGFloat(-angleDiff))
            
            var scale = CGPointGetDistance(point1: center, point2: touchLocation) / self.initialDistance
            let minimumScale = CGFloat(self.minimumSize) / min(self.initialBounds.size.width, self.initialBounds.size.height)
            scale = max(scale, minimumScale)
            let scaledBounds = CGRectScale(self.initialBounds, wScale: scale, hScale: scale)
            self.bounds = scaledBounds
            self.setNeedsDisplay()
        case .ended:
            break
        default:
            break
        }
    }
}

extension ATStickerView {
    /**
     *  Customize each editing handler's position.
     *  If not set, default position will be used.
     *  @note  It is your responsibility not to set duplicated position.
     *
     *  @param position The position for the handler.
     *  @param handler  The editing handler.
     */
    func setPosition(_ position: ATStickerViewPosition, forHandler handler: ATStickerViewHandler) {
        let origin = contentView.frame.origin
        let size = contentView.frame.size
        
        var handlerView:UIImageView?
        switch handler {
        case .close:
            handlerView = deleteControl
        case .rotate:
            handlerView = resizeControl
        case .flip:
            handlerView = flipControl
        }
        
        switch position {
        case .topLeft:
            handlerView?.center = origin
            handlerView?.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        case .topRight:
            handlerView?.center = CGPoint(x: origin.x + size.width, y: origin.y)
            handlerView?.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        case .bottomLeft:
            handlerView?.center = CGPoint(x: origin.x, y: origin.y + size.height)
            handlerView?.autoresizingMask = [.flexibleRightMargin, .flexibleTopMargin]
        case .bottomRight:
            handlerView?.center = CGPoint(x: origin.x + size.width, y: origin.y + size.height)
            handlerView?.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        }
        
        handlerView?.tag = position.rawValue
    }
    
    // MARK: - Private Methods
    private func setEnableClose(_ isEnable:Bool) {
        deleteControl.isHidden = !isEnable
        deleteControl.isUserInteractionEnabled = isEnable
    }
    
    private func setEnableResize(_ isEnable:Bool) {
        resizeControl.isHidden = !isEnable
        resizeControl.isUserInteractionEnabled = isEnable
    }
    
    private func setEnableFlip(_ isEnable:Bool) {
        flipControl.isHidden = !isEnable
        flipControl.isUserInteractionEnabled = isEnable
    }
}

// MARK: - UIGestureRecognizerDelegate
extension ATStickerView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UITapGestureRecognizer) || (otherGestureRecognizer is UITapGestureRecognizer) {
            return false
        }
        return true
    }
}
