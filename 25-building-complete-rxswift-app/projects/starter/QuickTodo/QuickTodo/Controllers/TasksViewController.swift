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
import RxDataSources
import Action
import NSObject_Rx

class TasksViewController: UIViewController, BindableType {
  
  @IBOutlet var tableView: UITableView!
  @IBOutlet var statisticsLabel: UILabel!
  @IBOutlet var newTaskButton: UIBarButtonItem!
  
  var viewModel: TasksViewModel!
  var dataSource: RxTableViewSectionedAnimatedDataSource<TaskSection>?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 60
    configureDataSource()
  }
  
  func bindViewModel() {
    dataSource.flatMap { dataSource in
      viewModel.sectionedItems
        .bind(to: tableView.rx.items(dataSource: dataSource))
        .disposed(by: self.rx.disposeBag)
    }
    
    newTaskButton.rx.action = viewModel.onCreateTask()
    
    tableView.rx.itemSelected
      .do(onNext: { [weak self] indexPath in
        self?.tableView.deselectRow(at: indexPath, animated: true)
      })
      .compactMap { [weak self] indexPath -> TaskItem? in
        guard let self = self else { return nil }
        guard let tasksItem = try self.dataSource?.model(at: indexPath) as? TaskItem else {
          return nil
        }
        return tasksItem
      }
      .bind(to: viewModel.editAction.inputs.asObserver())
      .disposed(by: rx.disposeBag)
      
  }
  
  private func configureDataSource() {
    dataSource = RxTableViewSectionedAnimatedDataSource<TaskSection>(configureCell: { [weak self]  dataSource, tableView, indexPath, item in
      
      guard let cell = tableView.dequeueReusableCell(withIdentifier: "TaskItemCell",
                                                     for: indexPath) as? TaskItemTableViewCell else {
        fatalError()
      }
      
      if let self = self {
        cell.configure(with: item,
                       action: self.viewModel.onToggle(task: item))
      }
      
      return cell
    }, titleForHeaderInSection: { dataSource, indexPath in
      dataSource.sectionModels[indexPath].model
    })
  }
}
