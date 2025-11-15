//  ARNavigationMapView.swift

import SwiftUI
import MapKit

struct ARNavigationMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let route: MKRoute?
    @Binding var startCoordinate: CLLocationCoordinate2D?
    @Binding var endCoordinate: CLLocationCoordinate2D?
    @Binding var currentLocationIndex: Int
    let instructions: [NavigationInstruction]
    @Binding var userLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        
        mapView.mapType = .standard
        mapView.showsBuildings = true
        mapView.showsTraffic = true
        mapView.showsPointsOfInterest = true
        
        let camera = MKMapCamera()
        camera.centerCoordinate = region.center
        camera.altitude = 300
        camera.pitch = 70
        mapView.setCamera(camera, animated: false)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)
        
        if let start = startCoordinate {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = start
            startAnnotation.title = "起点"
            uiView.addAnnotation(startAnnotation)
        }
        
        if let end = endCoordinate {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = end
            endAnnotation.title = "终点"
            uiView.addAnnotation(endAnnotation)
        }
        
        if let route = route {
            uiView.addOverlay(route.polyline)
        }
        
        if currentLocationIndex < instructions.count {
            let currentInstruction = instructions[currentLocationIndex]
            let annotation = MKPointAnnotation()
            annotation.coordinate = currentInstruction.coordinate
            annotation.title = "当前位置"
            annotation.subtitle = currentInstruction.instruction
            uiView.addAnnotation(annotation)
            
            let camera = MKMapCamera()
            camera.centerCoordinate = currentInstruction.coordinate
            camera.altitude = 200
            camera.pitch = 70
            uiView.setCamera(camera, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ARNavigationMapView
        
        init(_ parent: ARNavigationMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 8
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "NavigationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                if annotation.title == "当前位置" {
                    markerView.markerTintColor = .systemRed
                    markerView.glyphText = "current"
                } else if annotation.title == "起点" {
                    markerView.markerTintColor = .systemGreen
                    markerView.glyphText = "start"
                } else if annotation.title == "终点" {
                    markerView.markerTintColor = .systemBlue
                    markerView.glyphText = "end"
                }
            }
            
            return annotationView
        }
    }
}
