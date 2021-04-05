//
//  VideoCollectionViewCell.swift
//  VideoImageMerge
//
//  Created by Appernaut on 04/04/21.
//

import UIKit
import Photos

class VideoCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var thubnailImageView: UIImageView!

    func configure(_ video: Video) {
        thubnailImageView.layoutIfNeeded()
        thubnailImageView.loadImage(video.asset)
    }
}

extension UIImageView {
    func loadImage(_ asset: PHAsset) {
        guard frame.size != CGSize.zero else {
            image = nil
            return
        }
        
        if tag == 0 {
            image = nil
        } else {
            PHImageManager.default().cancelImageRequest(PHImageRequestID(tag))
        }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        
        let scale = UIScreen.main.scale
        let size = CGSize(width: frame.width * scale, height: frame.height * scale)
        
        let id = PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options) { [weak self] image, _ in
            self?.image = image
        }
        
        tag = Int(id)
    }
}
