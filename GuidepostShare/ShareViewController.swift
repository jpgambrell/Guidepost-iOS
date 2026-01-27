//
//  ShareViewController.swift
//  GuidepostShare
//
//  Created by John Gambrell on 1/27/26.
//

import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    private var hostingController: UIHostingController<ShareExtensionView>?
    private var viewModel: ShareExtensionViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create view model with extension context
        viewModel = ShareExtensionViewModel(extensionContext: extensionContext)
        
        // Create SwiftUI view with view model
        let shareView = ShareExtensionView(viewModel: viewModel!)
        hostingController = UIHostingController(rootView: shareView)
        
        // Add hosting controller as child
        if let hostingController = hostingController {
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.frame = view.bounds
            hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            hostingController.didMove(toParent: self)
        }
        
        // Extract images from share sheet
        viewModel?.extractImages()
    }
}
