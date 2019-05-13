import UIKit
import CoreData

class BadgesTableViewController: UITableViewController {
  
  var statusList: [BadgeStatus]!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    statusList = BadgeStatus.badgesEarned(runs: getRuns())
  }
  
  private func getRuns() -> [Run] {
    let fetchRequest: NSFetchRequest<Run> = Run.fetchRequest()
    let sortDescriptor = NSSortDescriptor(key: #keyPath(Run.timestamp), ascending: true)
    fetchRequest.sortDescriptors = [sortDescriptor]
    do {
      return try CoreDataStack.context.fetch(fetchRequest)
    } catch {
      return []
    }
  }
} // End of class

// extensions

extension BadgesTableViewController {
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return statusList.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: BadgeCell = tableView.dequeueReusableCell(for: indexPath)
    cell.status = statusList[indexPath.row]
    return cell
  }
}

extension BadgesTableViewController: SegueHandlerType {
  enum SegueIdentifier: String {
    case details = "BadgeDetailsViewController"
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segueIdentifier(for: segue) {
    case .details:
      let destination = segue.destination as! BadgeDetailsViewController
      let indexPath = tableView.indexPathForSelectedRow!
      destination.status = statusList[indexPath.row]
    }
  }
  
  override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
    guard let segue = SegueIdentifier(rawValue: identifier) else { return false }
    switch segue {
    case .details:
      guard let cell = sender as? UITableViewCell else { return false }
      return cell.accessoryType == .disclosureIndicator
    }
  }
}
