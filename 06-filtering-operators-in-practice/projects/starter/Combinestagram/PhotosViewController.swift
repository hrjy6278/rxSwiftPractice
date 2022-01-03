/// Copyright (c) 2020 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Photos
import RxSwift

class PhotosViewController: UICollectionViewController {

  // MARK: public properties
  var selectedPhotos: Observable<UIImage> {
    return selectedPhotosSubject.asObservable()
  }

  // MARK: private properties
  private let selectedPhotosSubject = PublishSubject<UIImage>()
  private let bag = DisposeBag()

  private lazy var photos = PhotosViewController.loadPhotos()
  private lazy var imageManager = PHCachingImageManager()

  private lazy var thumbnailSize: CGSize = {
    let cellSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
    return CGSize(width: cellSize.width * UIScreen.main.scale,
                  height: cellSize.height * UIScreen.main.scale)
  }()

  static func loadPhotos() -> PHFetchResult<PHAsset> {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: allPhotosOptions)
  }
  
  private func errorMessage() {
    alert(title: "사진앱에 접근할 수 없음", text: "권한을 다시 설정해주세요.")
    //alert는 completed 타입이기때문에 asObservable로 Observable바꿔줌
      .asObservable()
    //take는 5는 5초동안 변경사항을 감지하겠다는 것 이 시간이 지나면 completed를 받게 된다.
      .take(DispatchTimeInterval.seconds(5), scheduler: MainScheduler.instance)
    //5초뒤에는 onComleted가 호출될 것 임. 거기에 completed 되었을때의 행위를 넣어준다.
      .subscribe(onCompleted: {
        self.dismiss(animated: true, completion: nil)
        self.navigationController?.popViewController(animated: true)
      }).disposed(by: bag)
  }

  // MARK: View Controller
  override func viewDidLoad() {
    super.viewDidLoad()
    
    //사진앱 권한을 요청
    let authorized = PHPhotoLibrary.authorized.share()
    
    authorized.skipWhile { $0 == false } //사진권한이 false 인 경우 아래로 로직이 타지 않게된다.
    .take(1)       //1번만 true를 가져오게 되면 더이상 구독하지 않는다.
    .observeOn(MainScheduler.instance)
    .subscribe(onNext: { _ in
      self.photos = PhotosViewController.loadPhotos()
      self.collectionView.reloadData()
    }).disposed(by: bag)
    
    //사진앱 권한을 주지않았을때 에러메시지를 띄우게 된다.
    authorized
      .skip(1)
      .takeLast(1)
      .filter { $0 == false }
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { [weak self] _ in
        self?.errorMessage()
      }).disposed(by: bag)
      
    
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    selectedPhotosSubject.onCompleted()
  }

  // MARK: UICollectionView

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return photos.count
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

    let asset = photos.object(at: indexPath.item)
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCell

    cell.representedAssetIdentifier = asset.localIdentifier
    imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
      if cell.representedAssetIdentifier == asset.localIdentifier {
        cell.imageView.image = image
      }
    })

    return cell
  }

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let asset = photos.object(at: indexPath.item)

    if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
      cell.flash()
    }

    imageManager.requestImage(for: asset, targetSize: view.frame.size, contentMode: .aspectFill, options: nil, resultHandler: { [weak self] image, info in
      guard let image = image,
            let info = info else { return }

      if let isThumbnail = info[PHImageResultIsDegradedKey as NSString] as?
        Bool, !isThumbnail {
        self?.selectedPhotosSubject.onNext(image)
      }
    })
  }
}
