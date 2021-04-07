//
//  VideoEditingViewController.swift
//  VideoImageMerge
//
//  Created by Appernaut on 04/04/21.
//

import UIKit
import AVFoundation
import AVKit

class VideoEditingViewController: UIViewController {
    @IBOutlet weak var videoContentView: UIView!
    @IBOutlet weak var stickersContentView: UIView!
    @IBOutlet weak var videoeHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var videoWidthConstraint: NSLayoutConstraint!
    
    var video: Video?
    var playerItem: AVPlayerItem?
    var videoPlayer: AVPlayer?

    var index: Int = 0
    
    let gifs = ["https://i.pinimg.com/originals/03/59/a7/0359a7994e0dff219d7fd83007f88bd1.gif",
                "https://64.media.tumblr.com/4605dd961e72292f818ca0ed32cdc70b/tumblr_mydm1r9Twn1qkzb3jo1_500.gif",
                "https://cdn.pixilart.com/photos/large/e7bb9b4d00a2a4f.gif"]
    
    var selectedStickerView: ATStickerView? {
        willSet {
            if selectedStickerView != nil {
                selectedStickerView?.isHandlingControlsEnable = false
            }
        }
        didSet {
            guard let stickerView = selectedStickerView else { return }
            selectedStickerView?.isHandlingControlsEnable = true
            //selectedStickerView?.enableResizeControl = false
            selectedStickerView?.enableFlipControl = false
            selectedStickerView?.superview?.bringSubviewToFront(stickerView)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if videoPlayer == nil {
            setupVideoPlayer()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        videoPlayer?.pause()
    }
    
    @IBAction func addWasPressed(_ sender: Any) {
        if index == gifs.count { index = 0 }
        let sticker = ATStickerView(contentFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                    animatedImageURL: gifs[index])
        sticker.center = CGPoint(x: videoContentView.frame.width/2, y: videoContentView.frame.height/2)
        sticker.delegate = self
        stickersContentView.addSubview(sticker)
        self.selectedStickerView = sticker
        index = index + 1
    }
    
    @IBAction func mergeWasPressed(_ sender: Any) {
        let stickers = stickersContentView.subviews.compactMap { subview -> VideoOverlayImage? in
            if subview is ATStickerView, let url = (subview as! ATStickerView).contentURL {
                return VideoOverlayImage(url: url, frame: subview.frame)
            }
            return nil
        }
        
        VideoManager.shared.makeVideoFrom(video: VideoData(asset: playerItem!.asset, frame: videoContentView.bounds),
                                          images: stickers)
        { (url, error) in
            let player = AVPlayer(url: url!)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            self.present(playerViewController, animated: true) {
                playerViewController.player!.play()
            }
        }
    }

    private func setupVideoPlayer() {
        let currentFrameSize = currentVideoFrameSize()
        
        videoeHeightConstraint.constant = currentFrameSize.height
        videoWidthConstraint.constant = currentFrameSize.width
        
        videoPlayer = AVPlayer(playerItem: playerItem)
        
        let playerLayer = AVPlayerLayer(player: videoPlayer)
        playerLayer.frame = CGRect(x: 0, y: 0, width: currentFrameSize.width, height: currentFrameSize.height)
        playerLayer.videoGravity = .resizeAspect
        
        videoContentView.layer.addSublayer(playerLayer)
        videoContentView.bringSubviewToFront(stickersContentView)
        videoPlayer?.play()
    }
    
    private func currentVideoFrameSize() -> CGSize {
        guard let asset = playerItem?.asset as? AVURLAsset, let track = asset.tracks(withMediaType: AVMediaType.video).first else { return .zero }
        let trackSize      = track.naturalSize
        let videoViewSize  = videoContentView.superview!.bounds.size
        let trackRatio     = trackSize.width / trackSize.height
        let videoViewRatio = videoViewSize.width / videoViewSize.height
        
        var newSize: CGSize
        if videoViewRatio > trackRatio {
            newSize = CGSize(width: trackSize.width * videoViewSize.height / trackSize.height, height: videoViewSize.height)
        } else {
            newSize = CGSize(width: videoViewSize.width, height: trackSize.height * videoViewSize.width / trackSize.width)
        }
        
        let assetInfo = VideoManager.shared.orientationFromTransform(transform: track.preferredTransform)
        if assetInfo.isPortrait {
            let tempSize = newSize
            newSize.width = tempSize.height
            newSize.height = tempSize.width
        }
        
        return newSize
    }
}

extension VideoEditingViewController: ATStickerViewDelegate {
    func didTapContentView(_ stickerView: ATStickerView?) {
        self.selectedStickerView = stickerView
    }
    
    func didTapDeleteControl(_ stickerView: ATStickerView?) {
        //
    }
    
    func didTapFlipControl(_ stickerView: ATStickerView?) {
        //
    }
}
