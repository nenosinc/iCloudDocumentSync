//
//  DetailViewController.swift
//  Cloud Files
//
//  Created by Sam Spencer on 9/10/19.
//  Copyright © 2019 Sam Spencer. All rights reserved.
//

import UIKit
import CloudDocumentSync

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!


    func configureView() {
        // Update the user interface for the detail item.
        if let detail = detailItem {
            if let label = detailDescriptionLabel {
                label.text = detail.name
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        configureView()
    }

    var detailItem: iCloudDocument? {
        didSet {
            // Update the view.
            configureView()
        }
    }


}

