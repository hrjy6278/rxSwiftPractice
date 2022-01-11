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

import Foundation
import RxSwift

print("\n\n\n===== Schedulers =====\n")

let globalScheduler = ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global())
let bag = DisposeBag()
let animal = BehaviorSubject(value: "[dog]")

//animal
//  .dump()
//  .dumpingSubscription()
//  .disposed(by: bag)

animal
    .subscribeOn(MainScheduler.instance)
    .dump()
    .observeOn(globalScheduler)
    .dumpingSubscription()
    .disposed(by: bag)


// Start coding here

let fruit = Observable<String>.create { observer in
    observer.onNext("[Apple]")
    sleep(2)
    observer.onNext("[pineapple]")
    sleep(2)
    observer.onNext("[strawberry]")
    sleep(2)

    return Disposables.create()
}

//스케줄러의 함정
let animalsThread = Thread() {
    sleep(3)
    animal.onNext("[cat]")
    sleep(3)
    animal.onNext("[tiger]")
    sleep(3)
    animal.onNext("[fox]")
    sleep(3)
    animal.onNext("[leopard]")
}

animalsThread.name = "Animals Thread"
animalsThread.start()


//글로벌큐에서 옵저버블과 이벤트를 Emit하며 이를 수신받는 subscribe는 메인스레드에서 처리함.
fruit
    .subscribeOn(globalScheduler)
    .dump()
    .observeOn(MainScheduler.instance)
    .dumpingSubscription()
    .disposed(by: bag)

RunLoop.main.run(until: Date(timeIntervalSinceNow: 13))
