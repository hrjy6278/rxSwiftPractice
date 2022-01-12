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

import RealmSwift
import RxSwift
import RxRealm
import RxCocoa

class ListTimelineViewModel {
  private let bag = DisposeBag()
  private let fetcher: TimelineFetcher
  
  let list: ListIdentifier
  let account: Driver<TwitterAccount.AccountStatus>

  // MARK: - Input
  //뷰컨트롤러가 중지를 원할때 사용하는 Input
  var paused: Bool = false {
    didSet {
      fetcher.paused.accept(paused)
    }
  }

  // MARK: - Output
  //로컬에 저장된 트위터를 output으로 내보내는 프로퍼티
  private(set) var tweets: Observable<(AnyRealmCollection<Tweet>, RealmChangeset?)>!
  
  //트위터에 로그인이 되어있는지 여부를 output으로 전달
  private(set) var isLogined: Driver<Bool>!

  // MARK: - Init
  init(account: Driver<TwitterAccount.AccountStatus>,
       list: ListIdentifier,
       apiType: TwitterAPIProtocol.Type = TwitterAPI.self) {
    
    self.list = list
    self.account = account
    
    // fetch and store tweets
    fetcher = TimelineFetcher(account: account, list: list, apiType: apiType)
    bindOutput()
    
    //네트워킹을 통해 가져온 최신 트윗을 Realm으로 로컬에 저장하는 로직
    fetcher.timeline
      .subscribe(Realm.rx.add(update: .all))
      .disposed(by: bag)

  }

  // MARK: - Methods
  private func bindOutput() {
    // Bind tweets
    guard let realm = try? Realm() else { return }
    
    tweets = Observable.changeset(from: realm.objects(Tweet.self))
    
    // Bind if an account is available
    isLogined = account.map { status in
      switch status {
      case .authorized:
        return true
      case .unavailable:
        return false
      }
    }
    .asDriver()
  }
}
