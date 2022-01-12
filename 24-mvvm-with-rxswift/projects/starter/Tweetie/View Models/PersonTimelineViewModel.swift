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
import RxCocoa
import RxDataSources

class PersonTimelineViewModel {
  private let fetcher: TimelineFetcher
  private let disposeBag = DisposeBag()

  let username: String

  // MARK: - Input
  let account: Driver<TwitterAccount.AccountStatus>

  // MARK: - Output
  //챌린지2
  public lazy var tweets: Driver<[Tweet]> = {
    return self.fetcher.timeline
      .asDriver(onErrorJustReturn: [])
      .scan([]) { lastList, newList in
        return newList + lastList
      }
  }()
  
  public let title: Observable<String>
  public var tableViewSectionModel: Observable<[AnimatableSectionModel<String, Tweet>]>

  // MARK: - Init
  init(account: Driver<TwitterAccount.AccountStatus>, username: String, apiType: TwitterAPIProtocol.Type = TwitterAPI.self) {
    let titleSubject = BehaviorSubject<String>(value: "None Found")
    let sectionModel = BehaviorSubject<[AnimatableSectionModel<String, Tweet>]>(value: [])
    
    self.account = account
    self.username = username
    
    
    self.title = titleSubject.asObservable()
    self.tableViewSectionModel = sectionModel
    fetcher = TimelineFetcher(account: account, username: username, apiType: apiType)
    
    tweets
      .asObservable()
      .flatMapLatest { _ in Observable.just(username) }
      .bind(to: titleSubject.asObserver())
      .disposed(by: disposeBag)
    
    tweets
      .asObservable()
      .flatMap {
        Observable.from(optional: AnimatableSectionModel(model: "Tweet", items: $0)).toArray()
      }
      .bind(to: sectionModel)
      .disposed(by: disposeBag)
 
  }
}
