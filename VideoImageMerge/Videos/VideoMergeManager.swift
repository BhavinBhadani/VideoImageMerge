

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
        let outputSize: CGSize = video.frame.size
        var insertTime: CMTime = .zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var arrayLayerImages: [CALayer] = []
        
        // Init composition
        let mixComposition = AVMutableComposition()
        
        // Get video track
        guard let videoTrack = video.asset.tracks(withMediaType: AVMediaType.video).first else { return }
        
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
            let layerInstructions = instruction(videoCompositionTrack!,
                                                asset: video.asset,
                                                time: insertTime,
                                                duration: duration,
                                                maxRenderSize: outputSize)
            instructions.append(layerInstructions.videoCompositionInstruction)
            
            insertTime = CMTimeAdd(insertTime, duration)
        } catch {
            print("Load track error")
        }
        
        // Merge
        for image in images {
            let animatedImageLayer = CALayer()
            animatedImageLayer.frame = image.frame
            
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
                
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = instructions
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
    func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false
        
        switch [transform.a, transform.b, transform.c, transform.d] {
        case [0.0, 1.0, -1.0, 0.0]:
            assetOrientation = .right
            isPortrait = true
            
        case [0.0, -1.0, 1.0, 0.0]:
            assetOrientation = .left
            isPortrait = true
            
        case [1.0, 0.0, 0.0, 1.0]:
            assetOrientation = .up
            
        case [-1.0, 0.0, 0.0, -1.0]:
            assetOrientation = .down
            
        default:
            break
        }
        
        return (assetOrientation, isPortrait)
    }
    
    fileprivate func instruction(_ assetTrack: AVAssetTrack, asset: AVAsset, time: CMTime, duration: CMTime, maxRenderSize: CGSize) -> (videoCompositionInstruction: AVMutableVideoCompositionInstruction, isPortrait: Bool) {
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
        
        // Find out orientation from preffered transform.
        let assetInfo = orientationFromTransform(assetTrack.preferredTransform)
        
        // Calculate scale ratio according orientation.
        var scaleRatio = maxRenderSize.width / assetTrack.naturalSize.width
        if assetInfo.isPortrait {
            scaleRatio = maxRenderSize.height / assetTrack.naturalSize.height
        }
        
        // Set correct transform.
        var transform = CGAffineTransform(scaleX: scaleRatio, y: scaleRatio)
        transform = assetTrack.preferredTransform.concatenating(transform)
        layerInstruction.setTransform(transform, at: .zero)
        
        // Create Composition Instruction and pass Layer Instruction to it.
        let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
        videoCompositionInstruction.timeRange = CMTimeRangeMake(start: time, duration: duration)
        videoCompositionInstruction.layerInstructions = [layerInstruction]
        
        return (videoCompositionInstruction, assetInfo.isPortrait)
    }
    
    fileprivate func exportDidFinish(exporter: AVAssetExportSession?, videoURL: URL, completion:@escaping Completion) -> Void {
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
    func removeItemIfExisted(_ url: URL) -> Void {
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
