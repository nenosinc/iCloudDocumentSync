//
//  MasterViewController.swift
//  Cloud Files
//
//  Created by Sam Spencer on 9/10/19.
//  Copyright © 2019 Sam Spencer. All rights reserved.
//

import UIKit
import CloudDocumentSync

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil
    var objects = [CloudFile]()
    

    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        navigationItem.leftBarButtonItem = editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItem = addButton
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        iCloud.sharedCloud.delegate = self // Set this if you plan to use the delegate
        iCloud.sharedCloud.verboseLogging = true // We want detailed feedback about what's going on with iCloud, this is false by default
        iCloud.sharedCloud.setupiCloudDocumentSync(withUbiquityContainer: nil) // You must call this setup method before performing any document operations
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
        
        // This is done automatically when changes are made, but we want to make sure the view is always updated when presented
        // In your own app, this could be done when a manual refresh is requested, for example.
        iCloud.sharedCloud.updateFiles()
    }

    @objc
    func insertNewObject(_ sender: Any) {
        objects.insert(NSDate(), at: 0)
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
    }

    
    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let object = objects[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = object
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
                detailViewController = controller
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let object = objects[indexPath.row]
        cell.textLabel!.text = object.name
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            iCloud.sharedCloud.deleteDocument(objects[indexPath.row].name) { (error) in
                if let deleteError = error {
                    print("Error deleting document: \(deleteError)")
                } else {
                    iCloud.sharedCloud.updateFiles()
                    self.objects.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        iCloud.sharedCloud.retrieveCloudDocument(objects[indexPath.row].name) { cloudDocument, documentData, error in
            self.tableView.deselectRow(at: indexPath, animated: true)
            
            guard error == nil else {
                print("Error retrieveing document: \(error)")
                return
            }
            
            if let documentData = documentData {
                fileText = String(data: documentData, encoding: .utf8)
            }
            fileTitle = cloudDocument?.fileURL.lastPathComponent
            
            iCloud.sharedCloud.documentState(forFile: fileTitle) { documentState, userReadableDocumentState, error in
                if error == nil {
                    if documentState == .inConflict {
                        self.performSegue(withIdentifier: "showConflict", sender: self)
                        self.tableView.deselectRow(at: indexPath, animated: true)
                    } else {
                        self.performSegue(withIdentifier: "documentView", sender: self)
                        self.tableView.deselectRow(at: indexPath, animated: true)
                    }
                } else {
                    if let error = error {
                        print("Error retrieveing document state: \(error)")
                    }
                }
            }
        }
    }


}

extension MasterViewController: iCloudDelegate {
    
    func filesChanged(_ files: [CloudFile]) {
        // Get the query results
        print("Files: \(files)")
        
        objects = files
        
        // refreshControl.endRefreshing()
        tableView.reloadData()
    }
    
    func availabilityDidChange(toState cloudIsAvailable: Bool, withUbiquityToken ubiquityToken: Any?, withUbiquityContainer ubiquityContainer: URL?) {
        print("Cloud is available? \(cloudIsAvailable). Ubiquity container (\(ubiquityContainer?.absoluteString ?? "nil")) initialized. You may proceed to perform document operations.")
    }
    
    func iCloudAvailabilityDidChange(to isAvailable: Bool, token ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?) {
        if isAvailable == false {
            let alert = UIAlertController.init(title: "iCloud Unavailable", message: "iCloud is no longer available. Make sure that you are signed into a valid iCloud account.", preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "Okay", style: .default, handler: { (action) in
                alert.dismiss(animated: true, completion: nil)
            }))
            present(alert, animated: true, completion: nil)
        }

    }
    
    func fileUpdateDidBegin() {
        // No implementation required
    }
    
    func fileUpdateDidEnd() {
        // No implementation required
    }
    
    func fileConflictBetweenCloudFile(_ cloudFile: [String : Any]?, and localFile: [String : Any]?) {
        
    }
    
    func iCloudDidFinishInitializing(with ubiquityToken: UbiquityIdentityToken?, with ubiquityContainer: URL?) {
        
    }
    
    var iCloudQueryLimitedToFileExtension: [String] {
        get {
            return ["txt"]
        }
    }
    
}

