import SwiftUI
import ARKit


struct WallDetectionOverlay: View {
    @ObservedObject var viewModel: MeasurementViewModel
    let onWallSelected: (ARPlaneAnchor) -> Void
    
    var body: some View {
        ZStack {
            if viewModel.detectedWalls.isEmpty {
                EmptyWallView()
            } else {
                WallMarkersView(walls: viewModel.detectedWalls, onWallSelected: onWallSelected)
            }
        }
    }
}

private struct EmptyWallView: View {
    var body: some View {
        Text("壁面を探しています...")
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
    }
}

private struct WallMarkersView: View {
    let walls: [ARPlaneAnchor]
    let onWallSelected: (ARPlaneAnchor) -> Void
    
    var body: some View {
        ForEach(walls, id: \.identifier) { wall in
            WallIndicator(
                wall: wall,
                onTap: {
                    onWallSelected(wall)
                }
            )
            .position(
                x: CGFloat(wall.transform.columns.3.x * 500 + 200),
                y: CGFloat(wall.transform.columns.3.y * 500 + 400)
            )
        }
    }
}
