//
//  VideoMergeManager.swift
//  StickerMaker
//
//  Created by Appernaut on 31/03/21.
//  Copyright © 2021 Appernaut. All rights reserved.
//

import UIKit
import MediaPlayer
import MobileCoreServices
import AVFoundation

struct VideoOverlayImage {
    var url: String
    var frame: CGRect
}

struct VideoData {
    var asset: AVAsset
    var frame: CGRect
}

class VideoManager: NSObject {
    static let shared = VideoManager()
    
    let defaultSize = CGSize(width: 1920, height: 1080)
    typealias Completion = (URL?, Error?) -> Void
        
    func merge(video: VideoData, images: [VideoOverlayImage], completion:@escaping Completion) -> Void {
        makeVideoFrom(video: video, images: images, completion: completion)
    }
    
    //
    // Merge videos & images
    //
    func makeVideoFrom(video: VideoData, images: [VideoOverlayImage], completion:@escaping Completion) -> Void {
        var outputSize: CGSize = .zero
        var insertTime: CMTime = .zero
        var arrayLayerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        var arrayLayerImages: [CALayer] = []
                        
        // Init composition
        let mixComposition = AVMutableComposition()
        
        // Get video track
        guard let videoTrack = video.asset.tracks(withMediaType: AVMediaType.video).first else { return }
        
        let assetInfo = orientationFromTransform(transform: videoTrack.preferredTransform)
        
        var videoSize = videoTrack.naturalSize
        if assetInfo.isPortrait == true {
            videoSize.width = videoTrack.naturalSize.height
            videoSize.height = videoTrack.naturalSize.width
        }

        if videoSize.height > outputSize.height {
            outputSize = videoSize
        }

        if outputSize.width == 0 || outputSize.height == 0 {
            outputSize = defaultSize
        }
        
        // Get audio track
        var audioTrack: AVAssetTrack?
        if video.asset.tracks(withMediaType: AVMediaType.audio).count > 0 {
            audioTrack = video.asset.tracks(withMediaType: AVMediaType.audio).first
        }
        
        // Init video & audio composition track
        let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                   preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        let audioCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio,
                                                                   preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        do {
            let startTime = CMTime.zero
            let duration = video.asset.duration
            
            // Add video track to video composition at specific time
            try videoCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
                                                      of: videoTrack,
                                                      at: insertTime)
            
            // Add audio track to audio composition at specific time
            if let audioTrack = audioTrack {
                try audioCompositionTrack?.insertTimeRange(CMTimeRangeMake(start: startTime, duration: duration),
                                                          of: audioTrack,
                                                          at: insertTime)
            }
            
            // Add instruction for video track
            let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack!,
                                                                       asset: video.asset,
                                                                       standardSize: outputSize,
                                                                       atTime: insertTime)
            
            // Hide video track before changing to new track
            let endTime = CMTimeAdd(insertTime, duration)
            let timeScale = video.asset.duration.timescale
            let durationAnimation = CMTime.init(seconds: 1, preferredTimescale: timeScale)
            
            layerInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRange.init(start: endTime, duration: durationAnimation))
            
            arrayLayerInstructions.append(layerInstruction)
            
            // Increase the insert time
            insertTime = CMTimeAdd(insertTime, duration)
        } catch {
            print("Load track error")
        }
        
        // Merge
        for image in images {
            let animatedImageLayer = CALayer()
                        
            let aspectWidth  = outputSize.width/video.frame.width
            let aspectHeight = outputSize.height/video.frame.height
            let aspectRatio = min(aspectWidth, aspectHeight)

            let scaledWidth  = image.frame.width * aspectRatio
            let scaledHeight = image.frame.height * aspectRatio
//            let x = (outputSize.width - image.frame.width) / 2
//            let y = (outputSize.height - image.frame.height) / 2
            
            let cx = (image.frame.minX * aspectRatio) + (scaledWidth / 2)
            let cy = (image.frame.minY * aspectRatio) + (scaledHeight / 2)

            var iFrame = image.frame
            iFrame.size.width = scaledWidth
            iFrame.size.height = scaledWidth
            animatedImageLayer.frame = iFrame
            animatedImageLayer.position = CGPoint(x: cx, y: cy)
            
            if let animatedURL = URL(string: image.url), let animation = animatedImage(with: animatedURL) {
                animatedImageLayer.add(animation, forKey: "contents")
            }
            
            arrayLayerImages.append(animatedImageLayer)
        }
        
        // Init Video layer
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height)
        
        let parentlayer = CALayer()
        parentlayer.frame = CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height)
        
        parentlayer.addSublayer(videoLayer)
        
        // Add Image layers
        arrayLayerImages.forEach { parentlayer.addSublayer($0) }
        
        // Main video composition instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
                
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.renderSize = outputSize
        mainComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentlayer)
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        // Export to file
        let path = NSTemporaryDirectory().appending("stickers_video_merge.mov")
        let exportURL = URL(fileURLWithPath: path)
        
        // Remove file if existed
        FileManager.default.removeItemIfExisted(exportURL)
        
        let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = exportURL
        exporter?.outputFileType = .mov
        exporter?.shouldOptimizeForNetworkUse = true
        exporter?.videoComposition = mainComposition
        
        // Do export
        exporter?.exportAsynchronously() {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter: exporter, videoURL: exportURL, completion: completion)
            }
        }
    }
    
    private func animatedImage(with url: URL) -> CAKeyframeAnimation? {
        let animation = CAKeyframeAnimation(keyPath: #keyPath(CALayer.contents))
        
        var frames: [CGImage] = []
        var delayTimes: [CGFloat] = []
        var totalTime: CGFloat = 0.0
        
        guard let animatedSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("Can not get image source from the gif: \(url)")
            return nil
        }
        
        // get frame
        let frameCount = CGImageSourceGetCount(animatedSource)
        
        for i in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(animatedSource, i, nil) else {
                continue
            }
            
            guard let dic = CGImageSourceCopyPropertiesAtIndex(animatedSource, i, nil) as? [AnyHashable: Any] else { continue }
            guard let gifDic: [AnyHashable: Any] = dic[kCGImagePropertyGIFDictionary] as? [AnyHashable: Any] else { continue }
            let delayTime = gifDic[kCGImagePropertyGIFDelayTime] as? CGFloat ?? 0
            
            frames.append(frame)
            delayTimes.append(delayTime)
            
            totalTime += delayTime
        }
        
        if frames.count == 0 {
            return nil
        }
        
        assert(frames.count == delayTimes.count)
        
        var times: [NSNumber] = []
        var currentTime: CGFloat = 0
        
        for i in 0..<delayTimes.count {
            times.append(NSNumber(value: Double(currentTime / totalTime)))
            currentTime += delayTimes[i]
        }
        
        animation.keyTimes = times
        animation.values = frames
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = Double(totalTime)
        animation.repeatCount = .greatestFiniteMagnitude
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false
        
        return animation
    }
}

// MARK:- Private methods
extension VideoManager {
    func orientationFromTransform(transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation: UIImage.Orientation = .up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .down
        }
        return (assetOrientation, isPortrait)
    }
    
    fileprivate func videoCompositionInstructionForTrack(track: AVCompositionTrack, asset: AVAsset, standardSize:CGSize, atTime: CMTime) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
        
        let transform = assetTrack.preferredTransform
        let assetInfo = orientationFromTransform(transform: transform)
        
        var aspectFillRatio:CGFloat = 1
        if assetTrack.naturalSize.height < assetTrack.naturalSize.width {
            aspectFillRatio = standardSize.height / assetTrack.naturalSize.height
        }
        else {
            aspectFillRatio = standardSize.width / assetTrack.naturalSize.width
        }
        
        if assetInfo.isPortrait {
            let scaleFactor = CGAffineTransform(scaleX: aspectFillRatio, y: aspectFillRatio)
            
            let posX = standardSize.width/2 - (assetTrack.naturalSize.height * aspectFillRatio)/2
            let posY = standardSize.height/2 - (assetTrack.naturalSize.width * aspectFillRatio)/2
            let moveFactor = CGAffineTransform(translationX: posX, y: posY)
            
            instruction.setTransform(assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(moveFactor), at: atTime)
            
        } else {
            let scaleFactor = CGAffineTransform(scaleX: aspectFillRatio, y: aspectFillRatio)
            
            let posX = standardSize.width/2 - (assetTrack.naturalSize.width * aspectFillRatio)/2
            let posY = standardSize.height/2 - (assetTrack.naturalSize.height * aspectFillRatio)/2
            let moveFactor = CGAffineTransform(translationX: posX, y: posY)
            
            var concat = assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(moveFactor)
            
            if assetInfo.orientation == .down {
                let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                concat = fixUpsideDown.concatenating(scaleFactor).concatenating(moveFactor)
            }
            
            instruction.setTransform(concat, at: atTime)
        }
        return instruction
    }
    
    fileprivate func setOrientation(image:UIImage?, onLayer:CALayer, outputSize:CGSize) -> Void {
        guard let image = image else { return }
        
        if image.imageOrientation == UIImage.Orientation.up {
            // Do nothing
        }
        else if image.imageOrientation == UIImage.Orientation.left {
            let rotate = CGAffineTransform(rotationAngle: .pi/2)
            onLayer.setAffineTransform(rotate)
        }
        else if image.imageOrientation == UIImage.Orientation.down {
            let rotate = CGAffineTransform(rotationAngle: .pi)
            onLayer.setAffineTransform(rotate)
        }
        else if image.imageOrientation == UIImage.Orientation.right {
            let rotate = CGAffineTransform(rotationAngle: -.pi/2)
            onLayer.setAffineTransform(rotate)
        }
    }
    
    fileprivate func exportDidFinish(exporter:AVAssetExportSession?, videoURL:URL, completion:@escaping Completion) -> Void {
        if exporter?.status == AVAssetExportSession.Status.completed {
            print("Exported file: \(videoURL.absoluteString)")
            completion(videoURL,nil)
        }
        else if exporter?.status == AVAssetExportSession.Status.failed {
            print("Export Failed: \(exporter?.error)")
            completion(videoURL,exporter?.error)
        }
    }
}

extension FileManager {
    func removeItemIfExisted(_ url:URL) -> Void {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(atPath: url.path)
            }
            catch {
                print("Failed to delete file")
            }
        }
    }
}
