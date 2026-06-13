import MapKit
import SwiftUI

struct MapLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: AddLocationViewModel
    @State private var coordinate: LocationCoordinate
    @State private var isResolving = false

    init(viewModel: AddLocationViewModel) {
        self.viewModel = viewModel
        _coordinate = State(initialValue: viewModel.mapInitialCoordinate)
    }

    var body: some View {
        VStack(spacing: 0) {
            MapCoordinatePicker(coordinate: $coordinate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("地图选点")

            bottomPanel
        }
        .background(Color.photoBackground.ignoresSafeArea())
        .navigationTitle("地图选点")
        .photoInlineNavigationTitle()
        .onAppear {
            viewModel.updateMapSelectedCoordinate(coordinate)
        }
        .onChange(of: coordinate) { _, newCoordinate in
            viewModel.updateMapSelectedCoordinate(newCoordinate)
        }
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选中坐标")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.photoMutedText)
                    Text(coordinate.coordinateText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(Color.photoAccent)
            }

            HStack(spacing: 10) {
                coordinateBox(title: "latitude", value: coordinate.latitude)
                coordinateBox(title: "longitude", value: coordinate.longitude)
            }

            Button {
                Task { await useSelectedLocation() }
            } label: {
                Label(isResolving || viewModel.isLoading ? "读取地点中" : "使用此地点", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.photoAccent)
            .disabled(isResolving || viewModel.isLoading)
        }
        .padding(20)
        .background(Color.photoSurface.opacity(0.98))
    }

    private func coordinateBox(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.photoMutedText)
            Text(String(format: "%.6f", value))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func useSelectedLocation() async {
        isResolving = true
        let didApply = await viewModel.applyMapSelection(coordinate)
        isResolving = false
        if didApply {
            dismiss()
        }
    }
}

struct LocationMapPreview: View {
    let location: ShootingLocation

    var body: some View {
        StaticLocationMap(coordinate: LocationCoordinate(latitude: location.latitude, longitude: location.longitude))
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .accessibilityLabel("地点地图预览")
    }
}

private struct MapCoordinatePicker: UIViewRepresentable {
    @Binding var coordinate: LocationCoordinate

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.overrideUserInterfaceStyle = .dark
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .includingAll

        context.coordinator.annotation.title = "Selected location"
        context.coordinator.annotation.coordinate = coordinate.clLocationCoordinate
        mapView.addAnnotation(context.coordinator.annotation)
        context.coordinator.setInitialRegionIfNeeded(on: mapView, coordinate: coordinate)

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.45
        mapView.addGestureRecognizer(longPress)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateAnnotation(on: mapView, coordinate: coordinate)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapCoordinatePicker
        let annotation = MKPointAnnotation()
        private var didSetInitialRegion = false

        init(parent: MapCoordinatePicker) {
            self.parent = parent
        }

        func setInitialRegionIfNeeded(on mapView: MKMapView, coordinate: LocationCoordinate) {
            guard !didSetInitialRegion else { return }
            didSetInitialRegion = true
            let region = MKCoordinateRegion(
                center: coordinate.clLocationCoordinate,
                latitudinalMeters: 4_500,
                longitudinalMeters: 4_500
            )
            mapView.setRegion(region, animated: false)
        }

        func updateAnnotation(on mapView: MKMapView, coordinate: LocationCoordinate) {
            let nextCoordinate = coordinate.clLocationCoordinate
            if annotation.coordinate.distance(to: nextCoordinate) > 0.5 {
                annotation.coordinate = nextCoordinate
            }
            setInitialRegionIfNeeded(on: mapView, coordinate: coordinate)
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view as? MKMapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            updateSelection(to: coordinate, in: mapView, animated: true)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard (annotation as? MKPointAnnotation) === self.annotation else { return nil }

            let identifier = "selected-location-pin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = false
            view.isDraggable = true
            view.markerTintColor = .systemTeal
            view.glyphImage = UIImage(systemName: "camera.aperture")
            return view
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            didChange newState: MKAnnotationView.DragState,
            fromOldState oldState: MKAnnotationView.DragState
        ) {
            guard let coordinate = view.annotation?.coordinate else { return }
            switch newState {
            case .ending, .canceling:
                view.dragState = .none
                updateSelection(to: coordinate, in: mapView, animated: false)
            default:
                break
            }
        }

        private func updateSelection(
            to coordinate: CLLocationCoordinate2D,
            in mapView: MKMapView,
            animated: Bool
        ) {
            let nextCoordinate = LocationCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            annotation.coordinate = coordinate
            parent.coordinate = nextCoordinate
            if animated {
                mapView.setCenter(coordinate, animated: true)
            }
        }
    }
}

private struct StaticLocationMap: UIViewRepresentable {
    let coordinate: LocationCoordinate

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.overrideUserInterfaceStyle = .dark
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.pointOfInterestFilter = .includingAll
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate.clLocationCoordinate
        mapView.addAnnotation(annotation)

        let region = MKCoordinateRegion(
            center: coordinate.clLocationCoordinate,
            latitudinalMeters: 2_800,
            longitudinalMeters: 2_800
        )
        mapView.setRegion(region, animated: false)
    }
}

private extension LocationCoordinate {
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
