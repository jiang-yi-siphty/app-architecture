import UIKit

class FolderViewController: UITableViewController {
	
	var folder: Folder = Store.shared.rootFolder {
		didSet {
			tableView.reloadData()
			if folder === folder.store?.rootFolder {
				title = .recordings
			} else {
				title = folder.name
			}
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftItemsSupplementBackButton = true
		navigationItem.leftBarButtonItem = editButtonItem
		
		NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: Store.changedNotification, object: nil)
	}
	
	@objc func handleChangeNotification(_ notification: Notification) {
		// Handle changes to the current folder
		if let item = notification.object as? Folder, item === folder {
			let reason = notification.userInfo?[Item.changeReasonKey] as? String
			if reason == Item.removed, let nc = navigationController {
				nc.setViewControllers(nc.viewControllers.filter { $0 !== self }, animated: false)
			} else {
				folder = item
			}
		}
		
		// Handle changes to children of the current folder
		guard let userInfo = notification.userInfo, userInfo[Item.parentFolderKey] as? Folder === folder else {
			return
		}
		
		// Handle changes to contents
		if let changeReason = userInfo[Item.changeReasonKey] as? String {
			let oldValue = userInfo[Item.newValueKey]
			let newValue = userInfo[Item.oldValueKey]
			switch (changeReason, newValue, oldValue) {
			case let (Item.removed, _, (oldIndex as Int)?):
				tableView.deleteRows(at: [IndexPath(row: oldIndex, section: 0)], with: .right)
			case let (Item.added, (newIndex as Int)?, _):
				tableView.insertRows(at: [IndexPath(row: newIndex, section: 0)], with: .left)
			case let (Item.renamed, (newIndex as Int)?, (oldIndex as Int)?):
				tableView.moveRow(at: IndexPath(row: oldIndex, section: 0), to: IndexPath(row: newIndex, section: 0))
				tableView.reloadRows(at: [IndexPath(row: newIndex, section: 0)], with: .fade)
			default: tableView.reloadData()
			}
		} else {
			tableView.reloadData()
		}
	}
	
	var selectedItem: Item? {
		if let indexPath = tableView.indexPathForSelectedRow {
			return folder.contents[indexPath.row]
		}
		return nil
	}
	
	// MARK: - Segues and actions
	
	@IBAction func createNewFolder(_ sender: Any?) {
		modalTextAlert(title: .createFolder, accept: .create, placeholder: .folderName) { string in
			if let s = string {
				let newFolder = Folder(name: s, uuid: UUID())
				self.folder.add(newFolder)
			}
			self.dismiss(animated: true)
		}
	}
	
	@IBAction func createNewRecording(_ sender: Any?) {
		performSegue(withIdentifier: .showRecorder, sender: self)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let identifier = segue.identifier else { return }
		switch identifier {
		case .showFolder :
			guard
				let folderVC = segue.destination as? FolderViewController,
				let selectedFolder = selectedItem as? Folder
				else { fatalError() }
			folderVC.folder = selectedFolder
		case .showRecorder :
			guard let recordVC = segue.destination as? RecordViewController else { fatalError() }
			recordVC.folder = folder
		case .showPlayer :
			guard
				let playVC = (segue.destination as? UINavigationController)?.topViewController as? PlayViewController,
				let recording = selectedItem as? Recording
				else { fatalError() }
			playVC.recording = recording
			if let indexPath = tableView.indexPathForSelectedRow {
				tableView.deselectRow(at: indexPath, animated: true)
			}
		default:
			break
		}
	}
	
	// MARK: - Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return folder.contents.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = folder.contents[indexPath.row]
		let identifier = item is Recording ? "RecordingCell" : "FolderCell"
		let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
		cell.textLabel!.text = "\((item is Recording) ? "🔊" : "📁")  \(item.name)"
		return cell
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle , forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			folder.remove(folder.contents[indexPath.row])
		} else {
			print("Editing style: \(editingStyle.rawValue)")
		}
	}
	
	// MARK: UIStateRestoring
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		coder.encode(folder.uuidPath, forKey: .uuidPathKey)
	}
	
	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
		if let uuidPath = coder.decodeObject(forKey: stringName.uuidPath.rawValue) as? [UUID],
			let folder = Store.shared.item(atUUIDPath: uuidPath) as? Folder
		{
			self.folder = folder
		} else {
			if let index = navigationController?.viewControllers.index(of: self),
				index != 0
			{
				navigationController?.viewControllers.remove(at: index)
			}
		}
	}
	enum stringName: String {
		case uuidPath
		case type
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	static let showRecorder = "showRecorder"
	static let showPlayer = "showPlayer"
	static let showFolder = "showFolder"
	
	static let recordings = NSLocalizedString("Recordings", comment: "Heading for the list of recorded audio items and folders.")
	static let createFolder = NSLocalizedString("Create Folder", comment: "Header for folder creation dialog")
	static let folderName = NSLocalizedString("Folder Name", comment: "Placeholder for text field where folder name should be entered.")
	static let create = NSLocalizedString("Create", comment: "Confirm button for folder creation dialog")
}

