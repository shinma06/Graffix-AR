import SwiftUI
import ARKit

struct ARContentView: View {
    @StateObject private var viewModel: MeasurementViewModel
    @StateObject private var wallTargetingVM: WallTargetingViewModel
    private let arServices: ARServices
    
    init(viewModel: MeasurementViewModel,
         wallTargetingVM: WallTargetingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _wallTargetingVM = StateObject(wrappedValue: wallTargetingVM)
        self.arServices = ARServicesProvider()
    }
    
    var body: some View {
        ZStack {
            ARViewContainer(
                viewModel: viewModel,
                wallTargetingVM: wallTargetingVM,
                arServices: arServices
            )
            
            ReticuleMark(state: reticuleState)
                .position(x: UIScreen.main.bounds.width / 2,
                          y: UIScreen.main.bounds.height / 2)
            
            VStack(spacing: 0) {
                errorMessageBanner
                
                Spacer()
                
                if let distance = wallTargetingVM.currentDistance {
                    distanceText(distance)
                }
                
                Spacer()
                
                actionButton
                    .padding(.bottom, 34)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear(perform: startMeasurement)
        .onDisappear(perform: stopMeasurement)
    }
    
    private var errorMessageBanner: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.white)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .padding(.top, 60)
            }
        }
        .animation(.easeInOut, value: viewModel.errorMessage)
    }
    
    private func distanceText(_ distance: Float) -> some View {
        Text(String(format: "%.1f cm", distance * 100))
            .font(.title2)
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var actionButton: some View {
        Button(action: {
            Task {
                switch wallTargetingVM.targetingState {
                case .targeting:
                    await wallTargetingVM.lockWall()
                case .locked:
                    wallTargetingVM.unlockWall()
                default:
                    break
                }
            }
        }) {
            Text(wallTargetingVM.targetingState == .locked ? "固定を解除" : "壁面を固定")
                .padding()
                .background(buttonBackgroundColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(!isButtonEnabled)
        .opacity(isButtonEnabled ? 1.0 : 0.5)
        .padding()
    }
    
    private var buttonBackgroundColor: Color {
        switch wallTargetingVM.targetingState {
        case .locked: return .blue
        case .targeting: return .blue
        case .searching: return .gray
        }
    }
    
    private var isButtonEnabled: Bool {
        wallTargetingVM.targetingState == .locked || wallTargetingVM.targetingState == .targeting
    }
    
    private var reticuleState: ReticuleMark.State {
        switch wallTargetingVM.targetingState {
        case .searching: return .normal
        case .targeting: return .targeting
        case .locked: return .normal
        }
    }
    
    private func startMeasurement() {
        viewModel.startMeasurement()
    }
    
    private func stopMeasurement() {
        viewModel.stopMeasurement()
    }
}
