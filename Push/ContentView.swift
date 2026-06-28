//
//  ContentView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var region = MapDefaults.region

    var body: some View {
        Map(coordinateRegion: $region)
            .ignoresSafeArea()
    }
}

private enum MapDefaults {
    static let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        ),
        span: MKCoordinateSpan(
            latitudeDelta: latitudeDelta,
            longitudeDelta: longitudeDelta
        )
    )

    private static let latitude = 37.7749
    private static let longitude = -122.4194
    private static let latitudeDelta = 0.08
    private static let longitudeDelta = 0.08
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
