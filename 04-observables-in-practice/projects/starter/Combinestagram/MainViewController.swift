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

class MainViewController: UIViewController {
  
  @IBOutlet weak var imagePreview: UIImageView!
  @IBOutlet weak var buttonClear: UIButton!
  @IBOutlet weak var buttonSave: UIButton!
  @IBOutlet weak var itemAdd: UIBarButtonItem!
  
  private let disposeBag = DisposeBag()
  private let images = BehaviorRelay<[UIImage]>(value: [])
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    //변경사항을 구독한다. Observer를 등록하는 것 변경사항이 오면 이렇게 처리해라 라고 클로저에 담았다.
    images.subscribe (onNext: { [weak self] photos in
      guard let self = self else { return }
      self.updateUI(photos: photos)
      self.imagePreview.image = photos.collage(size: self.imagePreview.frame.size)
    })
      .disposed(by: disposeBag)
    
  }
  
  @IBAction func actionClear() {
    images.accept([])
  }
  
  @IBAction func actionSave() {
    guard let image = imagePreview.image else { return }
    //Single 특성으로 바꾼다.
    //저장이 성공적이면 성공이라는 얼러트를 띄우고 현재 보여지고 있던 사진들을 지운다.
    //저장이 실패하면 에러 얼러트를 띄우게 된다.
    PhotoWriter.save(image)
      .asSingle()
      .subscribe { [weak self] id in
        self?.showMessage("Save With id: \(id)")
        self?.actionClear()
      } onError: { [weak self] error in
        self?.showMessage("Error", description: error.localizedDescription)
      }.disposed(by: disposeBag)

    
    //Single로 Emit되는 값 받기
    PhotoWriter.singleSave(image)
      .subscribe { id in
        self.showMessage("save with id: \(id)")
        self.actionClear()
      } onError: { error in
        self.showMessage("error", description: error.localizedDescription)
      }.disposed(by: disposeBag)

  }
  
  @IBAction func actionAdd() {
    // 이미지를 최신으로 업데이트 하는 accept      해당 로직은 더미를 사용함.
    //    let newImages = images.value + [UIImage(named: "IMG_1907.jpg")!]
    //    images.accept(newImages)
    
    //사진을 선택하는 로직
    //여기서 PhotosVC에 있는 옵저버블을 구독하게 된다. 옵저버블에는 유저가 고른 사진이 있음.
    let photosViewController = storyboard!
      .instantiateViewController(withIdentifier: "PhotosViewController") as! PhotosViewController
    
    photosViewController.selectedPhotos.subscribe(onNext: { [weak self] newImage in
      guard let self = self else { return }
      self.images.accept(self.images.value + [newImage])
      
    },  onDisposed: {
      print("completed photo selection")
    })
    .disposed(by: disposeBag)
    
    navigationController?.pushViewController(photosViewController, animated: true)
    
  }
  
  func showMessage(_ title: String, description: String? = nil) {
    showAlert(title: title, message: description ?? "")
      .subscribe()
      .disposed(by: disposeBag)
  }
  
  private func updateUI(photos: [UIImage]) {
    buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
    buttonClear.isEnabled = photos.count > 0
    itemAdd.isEnabled = photos.count < 6
    
    title = photos.count > 0 ? "\(photos.count) photos" : "Collage"
  }
}
