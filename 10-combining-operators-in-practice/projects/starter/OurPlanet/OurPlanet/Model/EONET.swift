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

class EONET {
  static let API = "https://eonet.sci.gsfc.nasa.gov/api/v2.1"
  static let categoriesEndpoint = "/categories"
  static let eventsEndpoint = "/events"
  
  static func jsonDecoder(contentIdentifier: String) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.userInfo[.contentIdentifier] = contentIdentifier
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
  
  static func filteredEvents(events: [EOEvent], forCategory category: EOCategory) -> [EOEvent] {
    return events.filter { event in
      return event.categories.contains(where: { $0.id == category.id }) && !category.events.contains {
        $0.id == event.id
      }
    }
    .sorted(by: EOEvent.compareDates)
  }
  
  //EO 카테고리를 가져오는 부분
  static var categories: Observable<[EOCategory]> = {
    let request: Observable<[EOCategory]> = EONET.request(endpoint: categoriesEndpoint,
                                                          contentIdentifier: "categories")
    
    return request
      .map { return $0.sorted { $0.name < $1.name } }
    // 에러가 발생할시에 빈 배열을 구독자에게 내려보낸다
      .catchErrorJustReturn([])
    //share 를 써서 구독자가 늘어 날 경우 네트워크 요청을 추가로 하지않고 기존에 있던 응답을 준다.
      .share(replay: 1, scope: .forever)
  }()
  
  
  
  //네트워크 request 하는 부분
  static func request<T: Decodable>(endpoint: String,
                                    query: [String: Any] = [:],
                                    contentIdentifier: String) -> Observable<T> {
    do {
      guard let url = URL(string: API)?.appendingPathComponent(endpoint),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
              throw EOError.invalidURL(endpoint)
            }
      
      components.queryItems = try query.map { (key, value) -> URLQueryItem in
        guard let value = value as? CustomStringConvertible else {
          throw EOError.invalidParameter(key, value)
        }
        return URLQueryItem(name: key, value: value.description)
      }
      
      guard let finalURL = components.url else {
        throw EOError.invalidURL(endpoint)
      }
      
      let request = URLRequest(url: finalURL)
      
      //Observable을 리턴한다. RxCocoa를 활용하여 URLSession.rx로 Observable을 생성한다.
      // 다만 해당 리턴 타입은 Observable<(response: HTTPURLResponse, data: Data)>
      // 임으로 map을 하여 디코딩까지 하여 리턴하게 된다.
      return URLSession.shared.rx.response(request: request)
        .map { (response: HTTPURLResponse, data: Data) in
          let decoder = self.jsonDecoder(contentIdentifier: contentIdentifier)
          
          let envelope = try decoder.decode(EOEnvelope<T>.self, from: data)
          
          return envelope.content
        }
    } catch {
      return Observable.empty()
    }
  }
  
  
  //기후의 이벤트를 가지고 오기 위해 날짜와 지난 이벤트 인지 확인하고 네트워크 통신을 하는 메서드
  //기존 코드는 아래와 같으나 카테고리 별로 Event를 가져오기 위해 리팩토링을 진행
  //  private static func events(forLast days: Int, closed: Bool) -> Observable<[EOEvent]> {
  //    let query: [String: Any] = [
  //      "days": days,
  //      "status": (closed ? "closed" : "open")
  //    ]
  //
  //    let request: Observable<[EOEvent]> = EONET.request(endpoint: eventsEndpoint,
  //                                                       query: query,
  //                                                       contentIdentifier: "events")
  //    return request
  //      .catchErrorJustReturn([])
  //  }
  
  //리팩토링 진행 된 코드 parameter로 endpoint가 추가되었다.
  private static func events(forLast days: Int,
                             closed: Bool,
                             endpoint: String) -> Observable<[EOEvent]> {
    let query: [String: Any] = [
      "days": days,
      "status": (closed ? "closed" : "open")
    ]
    
    let request: Observable<[EOEvent]> = EONET.request(endpoint: endpoint,
                                                       query: query,
                                                       contentIdentifier: "events")
    return request.catchErrorJustReturn([])
  }
  
  //지난 이벤트와 진행중인 이벤트를 네트워크 통신을 하여 가져온 뒤 두개의 옵저버블을 concat으로 합친다.
  //concat은 순서적으로 실행되며 먼저 openEvents를 방출 한 뒤 complted 되면 closedEvents 를 방출하게 된다.
  static func events(forLast days: Int = 360, category: EOCategory) -> Observable<[EOEvent]> {
    
    
    let openEvents = events(forLast: days, closed: false, endpoint: category.endpoint)
    let closedEvents = events(forLast: days, closed: true, endpoint: category.endpoint)
    
    //    기존 코드
    //    concurency 하게 다운로드 하기 위해 리팩토링 진행
    //    return openEvents.concat(closedEvents)
    
    //    리팩토링 진행
    return Observable.of(openEvents, closedEvents)
      .merge()
      .reduce([]) { running, newEvents in
        running + newEvents
      }
  }
}
