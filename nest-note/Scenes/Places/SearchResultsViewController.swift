//
//  SearchResultsDelegate.swift
//  nest-note
//
//  Created by Colton Swapp on 8/8/25.
//

import UIKit
import MapKit
import CoreLocation

protocol SearchResultsDelegate: AnyObject {
    func searchResults(_ controller: SearchResultsViewController, didSelectMapItem mapItem: MKMapItem)
    func formatAddress(from placemark: CLPlacemark) -> String
    func formatDistance(_ distanceInMeters: Double) -> String
    func getCurrentLocation() -> CLLocation
}

class SearchResultsViewController: UITableViewController {
    weak var searchDelegate: SearchResultsDelegate?
    
    private var searchResults: [MKMapItem] = [] {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    private func setupTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = 60
    }
    
    func updateSearchResults(_ results: [MKMapItem]) {
        self.searchResults = results
    }
    
    // MARK: - Table View Data Source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "SearchResultCell")
        let mapItem = searchResults[indexPath.row]
        
        // Configure cell
        cell.textLabel?.text = mapItem.name ?? "Unknown Location"
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        
        // Create subtitle with address and distance
        if let searchDelegate = searchDelegate {
            let address = searchDelegate.formatAddress(from: mapItem.placemark)
            let currentLocation = searchDelegate.getCurrentLocation()
            let itemLocation = CLLocation(
                latitude: mapItem.placemark.coordinate.latitude,
                longitude: mapItem.placemark.coordinate.longitude
            )
            let distance = currentLocation.distance(from: itemLocation)
            let distanceString = searchDelegate.formatDistance(distance)
            
            cell.detailTextLabel?.text = "\(address) • \(distanceString)"
            cell.detailTextLabel?.font = .systemFont(ofSize: 14)
            cell.detailTextLabel?.textColor = .secondaryLabel
        }
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        
        return cell
    }
    
    // MARK: - Table View Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedMapItem = searchResults[indexPath.row]
        searchDelegate?.searchResults(self, didSelectMapItem: selectedMapItem)
    }
}
