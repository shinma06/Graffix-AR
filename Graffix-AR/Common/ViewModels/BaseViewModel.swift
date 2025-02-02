import SwiftUI
import Combine

class BaseViewModel: ObservableObject, ErrorHandlingViewModel {
    @Published var errorMessage: String?
    let errorHandler: ErrorHandling
    
    init(errorHandler: ErrorHandling = AppErrorHandler.shared) {
        self.errorHandler = errorHandler
    }
}
