//
//  ATGestureRecognizer.swift
//  StickerMaker
//
//  Created by Appernaut on 08/02/20.
//  Copyright © 2020 Appernaut. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

class ATGestureRecognizer: UIGestureRecognizer {
    var scale: CGFloat = 0.0
    var rotation: CGFloat = 0.0
    var anchorView: UIView? = nil
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
//        if event.touches(for: self)?.count ?? 0 > 1 {
//            state = .failed
//        }
        
        if touches.count != 1 {
            state = .failed
            return
        }
        
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = (state == .possible) ? .began : .changed

        guard let touch = touches.first, let anchor = anchorView else { return }
        let anchorViewCenter = anchor.center
        let currentPoint = touch.location(in: anchor.superview)
        let previousPoint = touch.previousLocation(in: anchor.superview)
        
        let currentRotation = atan2f((Float(currentPoint.y - anchorViewCenter.y)), (Float(currentPoint.x - anchorViewCenter.x)))
        let previousRotation = atan2f((Float(previousPoint.y - anchorViewCenter.y)), (Float(previousPoint.x - anchorViewCenter.x)))

        let currentRadius = distanceBetween(firstPoint: currentPoint, secondPoint: anchorViewCenter)
        let previousRadius = distanceBetween(firstPoint: previousPoint, secondPoint: anchorViewCenter)

        let newScale = currentRadius / previousRadius
        rotation = CGFloat(currentRotation - previousRotation)
        scale = CGFloat(newScale)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    func distanceBetween(firstPoint: CGPoint, secondPoint: CGPoint) -> Float {
        let deltaX = secondPoint.x - firstPoint.x
        let deltaY = secondPoint.y - firstPoint.y
        return Float(sqrt(deltaX * deltaX + deltaY * deltaY))
    }
    
    func resetProperties() {
        rotation = 0
        scale = 1
    }
}

