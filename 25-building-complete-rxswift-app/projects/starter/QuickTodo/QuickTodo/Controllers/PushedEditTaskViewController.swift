//
//  PushedEditTaskViewController.swift
//  QuickTodo
//
//  Created by KimJaeYoun on 2022/01/14.
//  Copyright © 2022 Ray Wenderlich. All rights reserved.
//

import UIKit

class PushedEditTaskViewController: UIViewController, BindableType {
 
  
  @IBOutlet weak var titleView: UITextView!
  
  var viewModel: PushedEditViewModel!
  
  func bindViewModel() {
    
  }
  
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
