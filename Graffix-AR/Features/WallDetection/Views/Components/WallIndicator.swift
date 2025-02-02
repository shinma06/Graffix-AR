import SwiftUI
import ARKit

struct WallIndicator: View {
    let wall: ARPlaneAnchor
    let onTap: () -> Void
    
    private enum Constants {
        static let iconSize: CGFloat = 40
        static let backgroundOpacity: Double = 0.5
        static let cornerRadius: CGFloat = 4
        static let padding: CGFloat = 4
    }
    
    var body: some View {
        VStack(spacing: Constants.padding) {
            indicatorIcon
            indicatorLabel
        }
        .onTapGesture(perform: onTap)
    }
    
    private var indicatorIcon: some View {
        Image(systemName: "square.dashed")
            .font(.system(size: Constants.iconSize))
            .foregroundColor(.green)
    }
    
    private var indicatorLabel: some View {
        Text("タップして固定")
            .font(.caption)
            .foregroundColor(.white)
            .padding(Constants.padding)
            .background(Color.black.opacity(Constants.backgroundOpacity))
            .cornerRadius(Constants.cornerRadius)
    }
}
