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

class ViewController: UIViewController {
    
    @IBOutlet private weak var tempartureChangedSwitch: UISwitch!
    @IBOutlet private var searchCityName: UITextField!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var humidityLabel: UILabel!
    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var cityNameLabel: UILabel!
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        style()
        
        ////        더미데이터 불러오기
        //        ApiController.shared.currentWeather(for: "Rxswift")
        //            .observeOn(MainScheduler.instance)
        //            .subscribe(onNext: { data in
        //                self.tempLabel.text = "\(data.temperature)° C"
        //                self.iconLabel.text = data.icon
        //                self.humidityLabel.text = "\(data.humidity)%"
        //                self.cityNameLabel.text = data.cityName
        //            })
        //            .disposed(by: disposeBag)
        //
        ////        텍스트필드를 사용한 FlatMap 검색결과를 flatMap을 하여 네트워크로 통신하는 옵저버블을 새롭게 만든다.
        //        searchCityName.rx.text.orEmpty
        //            .filter { $0.isEmpty == false }
        //            .flatMap { text in
        //                ApiController.shared.currentWeather(for: text)
        //                    .catchErrorJustReturn(.empty)
        //            }
        //            .observeOn(MainScheduler.instance)
        //            .subscribe(onNext: { data in
        //                self.tempLabel.text = "\(data.temperature)° C"
        //                self.iconLabel.text = data.icon
        //                self.humidityLabel.text = "\(data.humidity)%"
        //                self.cityNameLabel.text = data.cityName
        //            })
        //            .disposed(by: disposeBag)
        

        
        //Driver로 리팩토링진행
        let search = searchCityName.rx.controlEvent(.editingDidEndOnExit)
            .map { _ in self.searchCityName.text ?? "" }
            .filter { $0.isEmpty == false }
            .flatMapLatest { text in
                ApiController
                    .shared
                    .currentWeather(for: text)
                    .catchErrorJustReturn(.empty)
            }
        
        //챌린지1 섭씨 <-> 화씨 변경하는 스위치 추가
        //방법은 네트워크 요청시에 화씨로 달라는 것 과 섭씨를 받아서 화씨로 변경하는 것.
        //책에서는 두번째 방법을 권장.
            
        //스위치 벨류의 Observable 변수 추가
        let isFahrenheit = tempartureChangedSwitch.rx.value.asObservable()
        
        //날씨정보와, 스위치 벨류를 combine한다. 이때 화씨일경우 로직을 실행함.
        let combineObservable = Observable.combineLatest(search, isFahrenheit) { search, isFahrenheit -> ApiController.Weather in
            var newSearch = search
            if isFahrenheit {
                newSearch.temperature = (newSearch.temperature * Int(1.8)) + 32
            }
            return newSearch
        }.asDriver(onErrorJustReturn: .empty)
       
        //스위치 위치에 따른 섭씨 화씨 레이블 변경
        combineObservable
            .map { self.tempartureChangedSwitch.isOn ? "\($0.temperature)° F" : "\($0.temperature)° C" }
            .drive(tempLabel.rx.text)
            .disposed(by: disposeBag)
        
        combineObservable
            .map { $0.icon }
            .drive(iconLabel.rx.text)
            .disposed(by: disposeBag)
        
        combineObservable
            .map { "\($0.humidity)%" }
            .drive(humidityLabel.rx.text)
            .disposed(by: disposeBag)
        
        combineObservable
            .map { $0.cityName }
            .drive(cityNameLabel.rx.text)
            .disposed(by: disposeBag)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        Appearance.applyBottomLine(to: searchCityName)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Style
    
    private func style() {
        view.backgroundColor = UIColor.aztec
        searchCityName.attributedPlaceholder = NSAttributedString(string: "City's Name",
                                                                  attributes: [.foregroundColor: UIColor.textGrey])
        searchCityName.textColor = UIColor.ufoGreen
        tempLabel.textColor = UIColor.cream
        humidityLabel.textColor = UIColor.cream
        iconLabel.textColor = UIColor.cream
        cityNameLabel.textColor = UIColor.cream
    }
}
