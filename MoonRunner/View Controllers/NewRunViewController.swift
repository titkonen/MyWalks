import UIKit
import CoreLocation
import MapKit
import AVFoundation

class NewRunViewController: UIViewController {
  
  // Outlets
  @IBOutlet weak var launchPromptStackView: UIStackView!
  @IBOutlet weak var dataStackView: UIStackView!
  @IBOutlet weak var startButton: UIButton!
  @IBOutlet weak var stopButton: UIButton!
  @IBOutlet weak var distanceLabel: UILabel!
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var paceLabel: UILabel!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var mapContainerView: UIView!
  
  @IBOutlet weak var badgeStackView: UIStackView!
  @IBOutlet weak var badgeImageView: UIImageView!
  @IBOutlet weak var badgeInfoLabel: UILabel!
    
  //Properties
  private var run: Run?
  private let locationManager = LocationManager.shared
  private var seconds = 0
  private var timer: Timer?
  private var distance = Measurement(value: 0, unit: UnitLength.meters)
  private var locationList: [CLLocation] = []
  
  private var upcomingBadge: Badge!
  private let successSound: AVAudioPlayer = {
    guard let successSound = NSDataAsset(name: "success") else {
      return AVAudioPlayer()
    }
    return try! AVAudioPlayer(data: successSound.data)
  }()
  
  //Overrides
  override func viewDidLoad() {
    super.viewDidLoad()
    dataStackView.isHidden = true
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    timer?.invalidate()
    locationManager.stopUpdatingLocation()
  }
  
  //Functions
  private func startRun() {
    mapContainerView.isHidden = false
    mapView.removeOverlays(mapView.overlays)
    launchPromptStackView.isHidden = true
    dataStackView.isHidden = false
    startButton.isHidden = true
    stopButton.isHidden = false
    
    seconds = 0
    distance = Measurement(value: 0, unit: UnitLength.meters)
    locationList.removeAll()
    
    // This line affects Thread 1 fatal error. So I commented it out
    badgeStackView.isHidden = false
    upcomingBadge = Badge.next(for: 0)
    badgeImageView.image = UIImage(named: upcomingBadge.imageName)
    
    updateDisplay()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      self.eachSecond()
    }
    startLocationUpdates()
  }
  
  private func stopRun() {
    mapContainerView.isHidden = true
    launchPromptStackView.isHidden = false
    dataStackView.isHidden = true
    startButton.isHidden = false
    stopButton.isHidden = true
    // This line affects Thread 1 fatal error. So I commented it out
    badgeStackView.isHidden = true
    
    locationManager.stopUpdatingLocation()
  }
  
  private func saveRun() {
    let newRun = Run(context: CoreDataStack.context)
    newRun.distance = distance.value
    newRun.duration = Int16(seconds)
    newRun.timestamp = Date()
    
    for location in locationList {
      let locationObject = Location(context: CoreDataStack.context)
      locationObject.timestamp = location.timestamp
      locationObject.latitude = location.coordinate.latitude
      locationObject.longitude = location.coordinate.longitude
      newRun.addToLocations(locationObject)
    }
    
    CoreDataStack.saveContext()
    
    run = newRun
  }
  
  func eachSecond() {
    seconds += 1
    checkNextBadge()
    updateDisplay()
  }
  
  // Miles to kilometres .minutesPerMile
  private func updateDisplay() {
    let formattedDistance = FormatDisplay.distance(distance)
    let formattedTime = FormatDisplay.time(seconds)
    let formattedPace = FormatDisplay.pace(distance: distance, seconds: seconds, outputUnit: UnitSpeed.minutesPerKilometer)
    
    let distanceRemaining = upcomingBadge.distance - distance.value
    let formattedDistanceRemaining = FormatDisplay.distance(distanceRemaining)
    badgeInfoLabel.text = "\(formattedDistanceRemaining) until \(upcomingBadge.name)"
    
    distanceLabel.text = "Distance: \(formattedDistance)"
    timeLabel.text = "Time: \(formattedTime)"
    paceLabel.text = "Pace: \(formattedPace)"
  }
 
  private func startLocationUpdates() {
    locationManager.delegate = self
    locationManager.activityType = .fitness
    locationManager.distanceFilter = 10
    locationManager.startUpdatingLocation()
  }
  
  private func checkNextBadge() {
    let nextBadge = Badge.next(for: distance.value)
    if upcomingBadge != nextBadge {
      badgeImageView.image = UIImage(named: nextBadge.imageName)
      upcomingBadge = nextBadge
      successSound.play()
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
  }
  
  // FUNCTIONS ENDS
  
  // IBActions
  @IBAction func startTapped() {
    startRun()
  }
  
  @IBAction func stopTapped() {
    let alertController = UIAlertController(title: "End run?",
                                            message: "Do you wish to end your run?",
                                            preferredStyle: .actionSheet)
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alertController.addAction(UIAlertAction(title: "Save", style: .default) { _ in
      self.stopRun()
      self.saveRun()
      self.performSegue(withIdentifier: .details, sender: nil)
    })
    alertController.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
      self.stopRun()
      _ = self.navigationController?.popToRootViewController(animated: true)
    })
    
    present(alertController, animated: true)
  }

} // End of class

// extension 1
extension NewRunViewController: SegueHandlerType {
  enum SegueIdentifier: String {
    case details = "RunDetailsViewController"
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segueIdentifier(for: segue) {
    case .details:
      let destination = segue.destination as! RunDetailsViewController
      destination.run = run
    }
  }
}

// extension 2
extension NewRunViewController: CLLocationManagerDelegate {
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for newLocation in locations {
      let howRecent = newLocation.timestamp.timeIntervalSinceNow
      guard newLocation.horizontalAccuracy < 20 && abs(howRecent) < 10 else { continue }
      
      if let lastLocation = locationList.last {
        let delta = newLocation.distance(from: lastLocation)
        distance = distance + Measurement(value: delta, unit: UnitLength.meters)
        let coordinates = [lastLocation.coordinate, newLocation.coordinate]
        mapView.add(MKPolyline(coordinates: coordinates, count: 2))
        let region = MKCoordinateRegionMakeWithDistance(newLocation.coordinate, 500, 500)
        mapView.setRegion(region, animated: true)
      }
      
      locationList.append(newLocation)
    }
  }
}

// extension 3
extension NewRunViewController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let polyline = overlay as? MKPolyline else {
      return MKOverlayRenderer(overlay: overlay)
    }
    let renderer = MKPolylineRenderer(polyline: polyline)
    renderer.strokeColor = .blue
    renderer.lineWidth = 3
    return renderer
  }
}

