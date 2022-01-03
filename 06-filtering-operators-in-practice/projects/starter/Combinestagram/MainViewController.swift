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
import RxSwift
import RxRelay
import RxCocoa

class MainViewController: UIViewController {
  
  @IBOutlet weak var imagePreview: UIImageView!
  @IBOutlet weak var buttonClear: UIButton!
  @IBOutlet weak var buttonSave: UIButton!
  @IBOutlet weak var itemAdd: UIBarButtonItem!
  
  private let bag = DisposeBag()
  private let images = BehaviorRelay<[UIImage]>(value: [])
  //이미지 캐시 구현 (중복 사진 거르기)
  private var imageCache = [Int]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let imageShare = images.share(replay: 1, scope: .whileConnected)
    
    imageShare
      .throttle(RxTimeInterval.milliseconds(500), scheduler: MainScheduler.instance)
      .subscribe(onNext: { [weak self] photos in
        guard let self = self else { return }
        self.updateUI(photos: photos)
        self.imagePreview.image = photos.collage(size: self.imagePreview.frame.size)
      })
      .disposed(by: bag)

    //images 이 비어있을경우
    imageShare
      .skipWhile { $0.isEmpty == false }
      .subscribe(onNext: {_ in
        self.navigationItem.leftBarButtonItem?.image = nil
      }).disposed(by: bag)
  }
  
  @IBAction func actionClear() {
    images.accept([])
    imageCache = []
  }
  
  @IBAction func actionSave() {
    guard let image = imagePreview.image else { return }
    
    PhotoWriter.save(image)
      .subscribe(
        onSuccess: { [weak self] id in
          self?.showMessage("Saved with id: \(id)")
          self?.actionClear()
        },
        onError: { [weak self] error in
          self?.showMessage("Error", description: error.localizedDescription)
        }
      )
      .disposed(by: bag)
  }
  
  @IBAction func actionAdd() {
    // images.accept(images.value + [UIImage(named: "IMG_1907.jpg")!])
    
    
    let photosViewController = storyboard!.instantiateViewController(
      withIdentifier: "PhotosViewController") as! PhotosViewController
    
    navigationController!.pushViewController(photosViewController, animated: true)
    
    //share Observable 생성
    let newPhotos = photosViewController.selectedPhotos.share()
    
    newPhotos
      .takeWhile { [weak self] image in
        let count = self?.images.value.count ?? 0
        return count < 6
      }
      //filter 메서드로 방출된 조건에 따라 값을 필터링할 수 있다.
      //해당 로직은 가로로 더 긴 사진들만 필터링해온다.
      .filter { $0.size.width > $0.size.height }
    
    // data의 길이에 따라 필터링하고 캐쉬에 저장된 값이 없을 경우 추가한다.
      .filter { newImage in
        let length = newImage.pngData()?.count ?? 0
        guard self.imageCache.contains(length) == false else {
          return false
        }
        self.imageCache.append(length)
        return true
      }
      .subscribe(
        onNext: { [weak self] newImage in
          guard let images = self?.images else { return }
          images.accept(images.value + [newImage])
        },
        onDisposed: {
          print("completed photo selection")
        }
      )
      .disposed(by: bag)
    
    //네비게이션 좌측 아이콘 변경
    //변경감지된 아이템은 받지 않는다 completed 로 바뀌었기때문
    //completed 된 시점에 네비게이션 아이템을 업데이트 한다.
    newPhotos
      .ignoreElements()
      .subscribe { [weak self] in
        self?.updateNavigationIcon()
      }
      .disposed(by: bag)
  }
  
  
  func showMessage(_ title: String, description: String? = nil) {
    alert(title: title, text: description)
      .subscribe()
      .disposed(by: bag)
  }
  
  private func updateUI(photos: [UIImage]) {
    buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
    buttonClear.isEnabled = photos.count > 0
    itemAdd.isEnabled = photos.count < 6
    title = photos.count > 0 ? "\(photos.count) photos" : "Collage"
  }
  
  private func updateNavigationIcon() {
    let icon = imagePreview.image?
      .scaled(CGSize(width: 22, height: 22))
      .withRenderingMode(.alwaysOriginal)
    
    navigationItem.leftBarButtonItem = UIBarButtonItem(image: icon, style: .done, target: nil, action: nil)
    
  }
}
