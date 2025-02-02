import SwiftUI
import Combine

/// エラーハンドリング機能を提供するViewModelプロトコル
protocol ErrorHandlingViewModel: ObservableObject {
    /// 現在のエラーメッセージ
    var errorMessage: String? { get set }
    
    /// エラーハンドリングサービス
    var errorHandler: ErrorHandling { get }
    
    /// エラーを処理する
    func handleError(_ error: AppError)
}

extension ErrorHandlingViewModel {
    func handleError(_ error: AppError) {
        Task { @MainActor in
            errorHandler.handle(error)
            errorMessage = error.localizedDescription
            if let recovery = error.recoverySuggestion {
                errorMessage = (errorMessage ?? "") + "\n" + recovery
            }
        }
    }
}
