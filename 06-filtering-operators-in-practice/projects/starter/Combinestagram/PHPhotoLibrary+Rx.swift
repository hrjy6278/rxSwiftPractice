//
//  PHPhotoLibrary+Rx.swift
//  Combinestagram
//
//  Created by KimJaeYoun on 2022/01/03.
//  Copyright © 2022 Underplot ltd. All rights reserved.
//

import Foundation
import Photos
import RxSwift

//사진앱을 볼 수 있는 권한을 받으면 사진을 업데이트 할 수 있도록 만들기
extension PHPhotoLibrary {
  static var authorized: Observable<Bool> {
    return Observable.create { observer in
      
      if authorizationStatus() == .authorized {
        observer.onNext(true)
        observer.onCompleted()
      } else {
        observer.onNext(false)
        requestAuthorization { newStatus in
          observer.onNext(newStatus == .authorized)
          observer.onCompleted()
        }
      }
      
      return Disposables.create()
    }
  }
}
