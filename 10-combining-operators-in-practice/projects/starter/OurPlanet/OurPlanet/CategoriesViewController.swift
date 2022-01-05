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

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

  @IBOutlet var tableView: UITableView!
  
  //카테고리를 가지고있는 서브젝트 생성 및 dispose Bag
  private let categories = BehaviorRelay<[EOCategory]>(value: [])
  private let disposeBag = DisposeBag()

  override func viewDidLoad() {
    super.viewDidLoad()

    //카테고리가 변경되면 어떻게 하겠다. 구독하는 부분
    categories
      .asObservable()
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { [weak self] _ in
        self?.tableView.reloadData()
      })
      .disposed(by: disposeBag)
    
    startDownload()
  }

  func startDownload() {
//    카테고리를 네트워크통신하는 옵저버블을 바인딩 하는 부분 구독자가 생겼기 때문에 설정해 두었던 로직이 실행된다.
//    기존 코드는 아래와 같으며 리팩토링을 진행한다. 이벤트도 가져와야 하기 때문에
//    let eoCategories = EONET.categories
//      .bind(to: categories)
//      .disposed(by: disposeBag)
    
    let eoCategories = EONET.categories
//   기존 코드는 다음과 같으나 리팩토링을 진행함. 카테고리 별로 이벤트를 다운받기 위해서!
//   let downoloadedEvents = EONET.events()
    
//    리팩토링 진행한 코드
//    먼저 전체 카테고리를 가져온 뒤 flatMap으로 새로운 옵저버블을 만든게 된다.
//    그 후 하나의 시퀀스로 머지한다
    let downloadedEvents = eoCategories
      .flatMap { categories in
      return Observable.from(categories.map { EONET.events(category: $0) })
    }
      .merge(maxConcurrent: 2)
    
    
//    두개를 합치를 Observable 을 만든다. categories에 event를 넣는 것.
//    기존 코드는 이거고 리팩토링 진행..
//    let updatedCategories = Observable.combineLatest(eoCategories, downoloadedEvents) { categories, events -> [EOCategory] in
//      return categories.map { category in
//        var cat = category
//        cat.events = events.filter { event in
//          event.categories.contains(where: { $0.id == category.id })
//        }
//       return cat
//      }
//    }
    
//    리팩토링 진행된 코드.. 이부분은 너무 어려운듯...
   let updatedCategories = eoCategories.flatMap { categories in
      downloadedEvents.scan(categories) { updated, events in
        return updated.map { category in
          let eventForcategory = EONET.filteredEvents(events: events,
                                                      forCategory: category)
          if eventForcategory.isEmpty == false {
            var cat = category
            cat.events = cat.events + eventForcategory
            return cat
          }
          return category
        }
      }
    }
    
    //bind가 되니 subscibe가 되는 것 = 결국 Observer가 등록 되는 것이다.
    //concat이니 먼저 eoCategories가 값들을 Emit 하게 되고 그 뒤에 updatedCategories가 Emit 하게된다.
    eoCategories
      .concat(updatedCategories)
      .bind(to: categories)
      .disposed(by: disposeBag)
   
    
  }
  
  // MARK: UITableViewDataSource
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return categories.value.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
    
    let currentCategory = categories.value[indexPath.row]
    
    cell.textLabel?.text = "\(currentCategory.name) (\(currentCategory.events.count))"
    cell.accessoryType = currentCategory.events.count > 0 ? .disclosureIndicator : .none
    cell.detailTextLabel?.text = currentCategory.description
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    let category = categories.value[indexPath.row]
    
    tableView.deselectRow(at: indexPath, animated: true)
    
    guard category.events.isEmpty == false else { return }
    
    let eventsController = storyboard?.instantiateViewController(withIdentifier: "events") as! EventsViewController
    eventsController.title = category.name
    eventsController.events.accept(category.events)
    navigationController?.pushViewController(eventsController, animated: true)
  }
  
}

