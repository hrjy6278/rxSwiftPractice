//
//  UIViewController + Extension.swift
//  Combinestagram
//
//  Created by KimJaeYoun on 2022/01/03.
//  Copyright © 2022 Underplot ltd. All rights reserved.
//

import Foundation
import UIKit
import RxSwift

extension UIViewController {
  //얼러트를 Completable 옵저버블로 리턴
  func showAlert(title: String, message: String) -> Completable {
    return Completable.create { [weak self] observer in
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
      let closeAction = UIAlertAction(title: "Close", style: .default) { _ in
        observer(.completed)
      }
      alert.addAction(closeAction)
      self?.present(alert, animated: true, completion: nil)
      
      return Disposables.create {
        self?.dismiss(animated: true, completion: nil)
      }
    }
  }
}
