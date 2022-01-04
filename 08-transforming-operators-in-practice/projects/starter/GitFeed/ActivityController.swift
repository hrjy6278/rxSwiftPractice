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
import RxCocoa
import Kingfisher

func cacheFileURL(_ fileName: String) -> URL {
  return FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask)
    .first!
    .appendingPathComponent(fileName)
}

class ActivityController: UITableViewController {
  //이벤트 URL을 disk에 저장하기위한 프로퍼티이다.
  private let eventsFileURL = cacheFileURL("events.json")
  
  //새로운 데이터만 가져올 수 있도록 이전 네트워크 응답 헤더의 수신날짜를 저장하는 프로퍼티
  private let modifiedFileURL = cacheFileURL("modified.txt")
  private let lastModified = BehaviorRelay<String?>(value: nil)
  
  private let repo = "ReactiveX/RxSwift"

  private let events = BehaviorRelay<[Event]>(value: [])
  private let bag = DisposeBag()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = repo

    self.refreshControl = UIRefreshControl()
    let refreshControl = self.refreshControl!

    refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
    refreshControl.tintColor = UIColor.darkGray
    refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
    refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
    
    
    if let lastModifiedString = try? String(contentsOf: modifiedFileURL, encoding: .utf8) {
      lastModified.accept(lastModifiedString)
    }
    
    //로컬에 캐쉬 데이터가 있으면 해당 데이터를 불러오고, 아니면 새롭게 네트워크 요청
    if let eventsData = try? Data(contentsOf: eventsFileURL),
       let persistedEvents = try? JSONDecoder().decode([Event].self, from: eventsData) {
      events.accept(persistedEvents)
    } else {
      refresh()
    }
    
  }

  @objc func refresh() {
    DispatchQueue.global(qos: .default).async { [weak self] in
      guard let self = self else { return }
      self.fetchEvents(repo: self.repo)
    }
  }

  func fetchEvents(repo: String) {
    //옵저버블을 만든다. from으로  맵을 사용하여 URL -> URLRequest 로 변환시킴.
    let response = Observable.from([repo])
      .subscribeOn(CurrentThreadScheduler.instance)
      .map { urlString in
        return URL(string: "https://api.github.com/repos/\(urlString)/events")!
      }
    //기존에는 .map { URLRequest(url: $0) } 이였으나 헤더에 마지막 다운로드 시간을 넣는 로직 추가
      .map { [weak self] in
        var request = URLRequest(url: $0)
        if let modifiedHeader = self?.lastModified.value {
          request.addValue(modifiedHeader,
                           forHTTPHeaderField: "Last-Modified")
        }
        return request
      }
    // flatMap을 활용하여 새로운 옵저버블을 만든다.
    // 그리고 URLSession.rx를 활용하여 옵저버블을 만든다.
      .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
        return URLSession.shared.rx.response(request: request)
    // 이전에 네트워크 응답결과를 캐쉬로 가지고 있는다. 구독자가 새로 생기면 이전에 요청한 네트워크 응답을 리턴한다.
      }.share(replay: 1)
    
    //httpResponse Code가 200~300 성공 응답일시에 subscibe 하는 부분
    response
      .filter { response, _ in
      return 200..<300 ~= response.statusCode
    }
      .compactMap { _, data -> [Event]? in
      return try? JSONDecoder().decode([Event].self, from: data)
    }
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { [weak self] newEvents in
        self?.processEvents(newEvents)
      })
      .disposed(by: bag)

    //response header의 마지막 다운로드 시간을 저장하는 부분
    response
      .filter { response, _ in
        return 200..<400 ~= response.statusCode
      }
      .flatMap { response, _ -> Observable<String> in
        guard let headerValue = response.allHeaderFields["Last-Modified"] as? String else {
          return Observable.never()
        }
        return Observable.just(headerValue)
      }
      .subscribe(onNext: { [weak self] modifiedHeader in
        guard let self = self else { return }
        self.lastModified.accept(modifiedHeader)
        try? modifiedHeader.write(to: self.modifiedFileURL,
                                  atomically: true,
                                  encoding: .utf8)
      })
      .disposed(by: bag)
  }
  
  func processEvents(_ newEvents: [Event]) {
    //깃허브 네트워크 통신을 하고 난 뒤 Data를 View에 띄우는 작업
    var updatedEvents = newEvents + events.value
    if updatedEvents.count > 50 {
      updatedEvents = [Event](updatedEvents.prefix(upTo: 50))
    }
    
    events.accept(updatedEvents)
    tableView.reloadData()
    self.refreshControl?.endRefreshing()
    
    //eventsData를 내부 디스크에 저장한다.
    DispatchQueue.global().async {
      let encoder = JSONEncoder()
      if let eventsData = try? encoder.encode(updatedEvents) {
        try? eventsData.write(to: self.eventsFileURL, options: .atomic)
      }
    }
  }

  // MARK: - Table Data Source
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return events.value.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let event = events.value[indexPath.row]

    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
    cell.textLabel?.text = event.actor.name
    cell.detailTextLabel?.text = event.repo.name + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
    cell.imageView?.kf.setImage(with: event.actor.avatar, placeholder: UIImage(named: "blank-avatar"))
    return cell
  }
}
