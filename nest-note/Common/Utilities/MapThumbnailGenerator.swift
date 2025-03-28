import MapKit
import UIKit

final class MapThumbnailGenerator {
    static let shared = MapThumbnailGenerator()
    private init() {}
    
    enum ZoomLevel: Double {
        case veryClose = 1    // Building level (0.001)
        case close = 2        // Block level (0.002)
        case medium = 3       // Neighborhood level (0.005)
        case far = 4          // District level (0.01)
        case veryFar = 5      // City level (0.02)
        
        var span: Double {
            switch self {
            case .veryClose: return 0.001
            case .close: return 0.002
            case .medium: return 0.005
            case .far: return 0.01
            case .veryFar: return 0.02
            }
        }
    }
    
    func generateDynamicThumbnail(
        for coordinate: CLLocationCoordinate2D,
        visibleRegion: MKCoordinateRegion,
        completion: @escaping (UIImage?) -> Void
    ) {
        let size = CGSize(width: 300, height: 300)
        
        // Create light mode options
        let lightOptions = MKMapSnapshotter.Options()
        lightOptions.region = MKCoordinateRegion(
            center: coordinate,
            span: visibleRegion.span
        )
        lightOptions.size = size
        lightOptions.scale = UIScreen.main.scale
        lightOptions.pointOfInterestFilter = .includingAll
        lightOptions.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        
        // Create dark mode options
        let darkOptions = MKMapSnapshotter.Options()
        darkOptions.region = MKCoordinateRegion(
            center: coordinate,
            span: visibleRegion.span
        )
        darkOptions.size = size
        darkOptions.scale = UIScreen.main.scale
        darkOptions.pointOfInterestFilter = .includingAll
        darkOptions.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        
        // Create both snapshots
        let lightSnapshotter = MKMapSnapshotter(options: lightOptions)
        let darkSnapshotter = MKMapSnapshotter(options: darkOptions)
        
        let group = DispatchGroup()
        var lightImage: UIImage?
        var darkImage: UIImage?
        
        group.enter()
        lightSnapshotter.start { [weak self] snapshot, error in
            defer { group.leave() }
            guard let self = self,
                  let snapshot = snapshot else { return }
            lightImage = self.addPinToSnapshot(snapshot, at: coordinate)
        }
        
        group.enter()
        darkSnapshotter.start { [weak self] snapshot, error in
            defer { group.leave() }
            guard let self = self,
                  let snapshot = snapshot else { return }
            darkImage = self.addPinToSnapshot(snapshot, at: coordinate)
        }
        
        group.notify(queue: .main) {
            guard let light = lightImage else {
                completion(nil)
                return
            }
            
            // Create image asset
            let asset = UIImageAsset()
            
            // Register light mode image
            asset.register(light, with: UITraitCollection(userInterfaceStyle: .light))
            
            // Register dark mode image if available
            if let dark = darkImage {
                asset.register(dark, with: UITraitCollection(userInterfaceStyle: .dark))
            }
            
            // Get the appropriate image for current trait collection
            let dynamicImage = asset.image(with: UITraitCollection.current)
            completion(dynamicImage)
        }
    }
    
    private func addPinToSnapshot(_ snapshot: MKMapSnapshotter.Snapshot, at coordinate: CLLocationCoordinate2D) -> UIImage? {
        let size = snapshot.image.size
        
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }
        
        // Draw map snapshot
        snapshot.image.draw(at: .zero)
        
        // Get point for annotation
        let point = snapshot.point(for: coordinate)
        
        // Create and configure marker annotation view
        let annotationView = MKMarkerAnnotationView(annotation: nil, reuseIdentifier: nil)
        annotationView.markerTintColor = .systemRed
        
        // Make sure the annotation view has a size
        annotationView.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        
        // Convert the annotation view to an image
        UIGraphicsBeginImageContextWithOptions(annotationView.bounds.size, false, 0)
        annotationView.drawHierarchy(in: annotationView.bounds, afterScreenUpdates: true)
        let annotationImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Draw the annotation image on the map
        if let annotationImage = annotationImage {
            let pinCenterOffset = CGPoint(x: annotationImage.size.width/2, y: annotationImage.size.height)
            let pinPoint = CGPoint(
                x: point.x - pinCenterOffset.x,
                y: point.y - pinCenterOffset.y
            )
            annotationImage.draw(at: pinPoint)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
} 
