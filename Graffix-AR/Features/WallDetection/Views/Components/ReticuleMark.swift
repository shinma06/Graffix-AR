// ReticuleMark.swift

import SwiftUI

// MARK: - Models

extension ReticuleMark {
    enum State {
        case normal
        case targeting
        case hidden
        
        var strokeColor: Color {
            switch self {
            case .normal:
                return .black
            case .targeting:
                return .green
            case .hidden:
                return .clear
            }
        }
    }
}

// MARK: - View

struct ReticuleMark: View {
    private enum Constants {
        static let size: CGFloat = 8
        static let strokeWidth: CGFloat = 2
        static let backgroundOpacity: Double = 0.5
    }
    
    let state: State
    
    var body: some View {
        Circle()
            .strokeBorder(state.strokeColor, lineWidth: Constants.strokeWidth)
            .frame(width: Constants.size, height: Constants.size)
            .background(
                Circle()
                    .fill(Color.white.opacity(Constants.backgroundOpacity))
                    .frame(width: Constants.size, height: Constants.size)
            )
            .opacity(state == .hidden ? 0 : 1)
    }
}
