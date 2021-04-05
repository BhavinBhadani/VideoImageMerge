//
//  ViewController.swift
//  VideoImageMerge
//
//  Created by Appernaut on 04/04/21.
//

import UIKit
import Photos

class ViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    
    private let library = VideosLibrary()
    private var videos: [Video] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        requestAndFetchAssets()
    }
    
    private func canAccessPhotoLib() -> Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized
    }
    
    func requestAuthorizationForPhotoAccess(authorized: @escaping () -> Void, rejected: @escaping () -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    authorized()
                } else {
                    rejected()
                }
            }
        }
    }
    
    func showDialog(okAction: UIAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil),
                           cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil),
                           title: String? = "Access App",
                           message: String? = "Stickers wants to access Photo Library") {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        if #available(iOS 13.0, *) {
            self.overrideUserInterfaceStyle = .light
        }
        self.present(alertController, animated: true)
    }
    
    func fetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }
    
    func openIphoneSetting() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
    }

    private func requestAndFetchAssets() {
        if canAccessPhotoLib() {
            self.fetchVideos()
        } else {
            let alertController = UIAlertController(title: "", message: "This app wants to access Photo Library", preferredStyle: .alert)
            

            let okAction = UIAlertAction(
                title: "Ok",
                style: .default) { (_) in
                self.requestAuthorizationForPhotoAccess(authorized: self.fetchVideos, rejected: self.openIphoneSetting)
            }
            
            let cancelAction = UIAlertAction(
                title: "Cancel",
                style: .cancel,
                handler: nil)
            
            alertController.addAction(okAction)
            alertController.addAction(cancelAction)
            if #available(iOS 13.0, *) {
                self.overrideUserInterfaceStyle = .light
            }
            present(alertController, animated: true)
        }
    }
    
    private func fetchVideos() {
        library.reload {
            self.videos = self.library.items
            self.collectionView.reloadData()
        }
    }
}

// MARK: UICollectionViewDataSource
extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCollectionViewCell", for: indexPath) as! VideoCollectionViewCell
        cell.configure(videos[indexPath.row])
        return cell
    }
}

// MARK: UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let video = videos[indexPath.row]
        video.fetchPlayerItem { [weak self] item in
            let vc = self?.storyboard?.instantiateViewController(withIdentifier: "VideoEditingViewController") as! VideoEditingViewController
            vc.video = video
            vc.playerItem = item
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension ViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = (collectionView.bounds.width - 3) / 4
        return CGSize(width: floor(cellWidth), height: floor(cellWidth))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
}
