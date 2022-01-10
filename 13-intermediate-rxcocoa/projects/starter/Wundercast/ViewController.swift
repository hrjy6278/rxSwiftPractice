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
import MapKit
import CoreLocation

class ViewController: UIViewController {
    @IBOutlet private var mapView: MKMapView!
    @IBOutlet private var mapButton: UIButton!
    @IBOutlet private var geoLocationButton: UIButton!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private var searchCityName: UITextField!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var humidityLabel: UILabel!
    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var cityNameLabel: UILabel!
    
    private let bag = DisposeBag()
    private let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        style()
        
        //MapButton을 누르면 MapView가 띄워지게끔 하는 로직
        mapButton.rx.tap
            .subscribe(onNext: {
                self.mapView.isHidden.toggle()
            })
            .disposed(by: bag)
        
        //MKMapView 델리게이트 프록시가 핸들링 할 수 없는 델리게이트 메서드 들을 수신하고 처리할 로직
        mapView.rx.setDelegate(self)
            .disposed(by: bag)
        
        //맵뷰의 지역이 바뀌었을때 실행하는 Observable<CLLocation>
        let mapInput = mapView.rx.regionDidChangeAnimated
            .skip(1)
            .map { _ in
                CLLocation(latitude: self.mapView.centerCoordinate.latitude,
                           longitude: self.mapView.centerCoordinate.longitude)
            }
        
        //사용자의 위치정보를 가져올때 실행되는 Observable<CLLocation>
        let geoInput = geoLocationButton.rx.tap
            .flatMapLatest { _ in
                self.locationManager.rx.getCurrentLocation()
            }
    
        //사용자의 위치 데이터를 얻기 위한 권한 얻기 로직
        let geoSearch = Observable.merge(mapInput, geoInput)
                    .flatMapLatest { location in
                        ApiController
                            .shared
                            .currentWeather(at: location.coordinate)
                            .catchErrorJustReturn(.empty)
                    }
        
        let searchInput = searchCityName.rx
            .controlEvent(.editingDidEndOnExit)
            .map { self.searchCityName.text ?? "" }
            .filter { !$0.isEmpty }
        
        
        let textSearch = searchInput.flatMap { city in
            ApiController
                .shared
                .currentWeather(for: city)
                .catchErrorJustReturn(.empty)
        }
        
//        이전 코드 리팩토링 진행
//        let search = searchInput
//            .flatMapLatest { text in
//                ApiController.shared
//                    .currentWeather(for: text)
//                    .catchErrorJustReturn(.empty)
//            }
//            .asDriver(onErrorJustReturn: .empty)
        
        let search = Observable.merge(geoSearch, textSearch)
            .asDriver(onErrorJustReturn: .empty)
        
        
        
        //네트워크 통신중인지 아닌지 판단하는 옵저버블
        //기존 코드.. 리팩토링 진행
//        let running = Observable.merge(searchInput.map { _ in true },
//                                       search.map { _ in false }.asObservable())
//            .startWith(true)
//            .asDriver(onErrorJustReturn: false)
        
        let running = Observable.merge(searchInput.map { _ in true },
                                       search.map { _ in false }.asObservable(),
                                       mapInput.map { _ in true },
                                       geoInput.map { _ in true })
            .startWith(true)
            .asDriver(onErrorJustReturn: false)
        
        //네트워크 통신에 따른 레이블들을 숨기거나 보여주게 하는 로직
        running
            .skip(1)
            .drive(activityIndicator.rx.isAnimating)
            .disposed(by: bag)
        
        running
            .drive(tempLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(iconLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(humidityLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(cityNameLabel.rx.isHidden)
            .disposed(by: bag)
        
        
        search.map { "\($0.temperature)° C" }
        .drive(tempLabel.rx.text)
        .disposed(by: bag)
        
        search.map(\.icon)
            .drive(iconLabel.rx.text)
            .disposed(by: bag)
        
        search.map { "\($0.humidity)%" }
        .drive(humidityLabel.rx.text)
        .disposed(by: bag)
        
        search.map(\.cityName)
            .drive(cityNameLabel.rx.text)
            .disposed(by: bag)
        
        //검색 결과를 mapView에 표시하기 위하여 추가된 로직
        search
            .map { $0.overlay() }
            .drive(mapView.rx.overlay)
            .disposed(by: bag)
        
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

//MKMapView의 Delegate 중 리턴타입이 있는 메서드들만 따로 정의
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let overlay = overlay as? ApiController.Weather.Overlay else {
            return MKOverlayRenderer()
        }
        
        return ApiController.Weather.OverlayView(overlay: overlay,
                                                 overlayIcon: overlay.icon)
    }
}
