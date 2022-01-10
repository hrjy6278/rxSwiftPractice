/// Copyright (c) 2019 Razeware LLC
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
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import MapKit
import RxSwift
import RxCocoa

extension MKMapView: HasDelegate { }

class RxMKMapViewDelegateProxy: DelegateProxy<MKMapView, MKMapViewDelegate>, DelegateProxyType, MKMapViewDelegate {
    static func registerKnownImplementations() {
        register {
            RxMKMapViewDelegateProxy(mapView: $0)
        }
    }
    
    
    weak public private(set) var mapView: MKMapView?
    
    public init(mapView: ParentObject) {
        self.mapView = mapView
        super.init(parentObject: mapView, delegateProxy: RxMKMapViewDelegateProxy.self)
    }
    
}

public extension Reactive where Base: MKMapView {
    var delegate: DelegateProxy<MKMapView, MKMapViewDelegate> {
        return RxMKMapViewDelegateProxy.proxy(for: base)
    }
    
    //리턴타입이 있는 델리게이트 메서드를 구현한 Delegate를 셋업 하는 부분
    func setDelegate(_ delegate: MKMapViewDelegate) -> Disposable {
        RxMKMapViewDelegateProxy.installForwardDelegate(delegate,
                                                        retainDelegate: false,
                                                        onProxyForObject: base)
    }
    
    // 오버레이 속성을 바인딩 할수 있는 속성
    var overlay: Binder<MKOverlay> {
        Binder(base) { mapView, overlay in
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlay(overlay)
        }
    }
    
    //사용자가 지도를 드래그 할때마다 호출되는 메서드를 구현한 ControlEvent
    var regionDidChangeAnimated: ControlEvent<Bool> {
        let source = delegate.methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionDidChangeAnimated:)))
            .map { parameters in
                return parameters[1] as? Bool ?? false
            }
        return ControlEvent(events: source)
    }
}


