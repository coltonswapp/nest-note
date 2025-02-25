import UIKit
import MapKit
import CoreLocation

final class AddressActionHandler {
    private static let geocoder = CLGeocoder()
    
    static func presentAddressOptions(
        from viewController: UIViewController,
        sourceView: UIView,
        address: String,
        coordinate: CLLocationCoordinate2D? = nil,
        onCopy: (() -> Void)? = nil
    ) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Open in Maps
        let mapsAction = UIAlertAction(title: "Open in Maps", style: .default) { _ in
            if let coordinate = coordinate {
                openInMaps(address: address, coordinate: coordinate)
            } else {
                // Geocode the address
                geocoder.geocodeAddressString(address) { placemarks, error in
                    if let location = placemarks?.first?.location {
                        openInMaps(address: address, coordinate: location.coordinate)
                    }
                }
            }
        }
        actionSheet.addAction(mapsAction)
        
        // Open in Google Maps
        let googleMapsAction = UIAlertAction(title: "Open in Google Maps", style: .default) { _ in
            if let coordinate = coordinate {
                // Use coordinate-based URL
                if let url = URL(string: "comgooglemaps://?q=@\(coordinate.latitude),\(coordinate.longitude)") {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        // Open in browser if Google Maps app is not installed
                        if let webUrl = URL(string: "https://maps.google.com/?q=@\(coordinate.latitude),\(coordinate.longitude)") {
                            UIApplication.shared.open(webUrl)
                        }
                    }
                }
            } else {
                // Fallback to address-based URL if no coordinates
                let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "comgooglemaps://?q=\(encodedAddress)") {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        if let webUrl = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedAddress)") {
                            UIApplication.shared.open(webUrl)
                        }
                    }
                }
            }
        }
        
        // Copy Address
        let copyAction = UIAlertAction(title: "Copy Address", style: .default) { _ in
            UIPasteboard.general.string = address
            onCopy?()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(googleMapsAction)
        actionSheet.addAction(copyAction)
        actionSheet.addAction(cancelAction)
        
        // For iPad support
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = sourceView.bounds
        }
        
        HapticsHelper.lightHaptic()
        viewController.present(actionSheet, animated: true)
    }
    
    private static func openInMaps(address: String, coordinate: CLLocationCoordinate2D) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = address
        
        // Set launch options to show the pin and get directions
        let launchOptions = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
    }
} 
