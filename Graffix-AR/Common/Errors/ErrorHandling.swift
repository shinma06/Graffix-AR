import Foundation
import UIKit

protocol ErrorHandling: AnyObject {
    func handle(_ error: AppError)
    func recover(from error: AppError) async throws
    func showError(_ error: AppError)
    func logError(_ error: AppError)
}

final class AppErrorHandler: ErrorHandling {
    static let shared = AppErrorHandler()
    private var errorLogger: ErrorLogging
    private var errorPresenter: ErrorPresenting
    
    init(
        errorLogger: ErrorLogging = DefaultErrorLogger(),
        errorPresenter: ErrorPresenting = DefaultErrorPresenter()
    ) {
        self.errorLogger = errorLogger
        self.errorPresenter = errorPresenter
    }
    
    func handle(_ error: AppError) {
        logError(error)
        showError(error)
        
        // エラー種別に応じた特別な処理
        switch error {
        case .ar(.trackingStateChanged(let state)) where state == .normal:
            errorPresenter.dismissError()
        case .system(.memoryWarning):
            NotificationCenter.default.post(
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
        default:
            break
        }
    }
    
    func recover(from error: AppError) async throws {
        switch error {
        case .ar(.trackingStateChanged):
            try await resetARSession()
        case .sensor(.calibrationRequired):
            try await calibrateSensors()
        case .system(.memoryWarning):
            try await cleanupMemory()
        default:
            // デフォルトの回復処理
            try await defaultRecovery(for: error)
        }
    }
    
    func showError(_ error: AppError) {
        errorPresenter.present(error)
    }
    
    func logError(_ error: AppError) {
        errorLogger.log(error)
    }
    
    // MARK: - Private Methods
    
    private func resetARSession() async throws {
        // ARSessionのリセット処理
    }
    
    private func calibrateSensors() async throws {
        // センサーキャリブレーション
    }
    
    private func cleanupMemory() async throws {
        // メモリクリーンアップ
    }
    
    private func defaultRecovery(for error: AppError) async throws {
        // デフォルトの回復処理
    }
}

// MARK: - Error Logging

protocol ErrorLogging {
    func log(_ error: AppError)
}

struct DefaultErrorLogger: ErrorLogging {
    func log(_ error: AppError) {
        // 実際のログ実装
        print("Error: \(error.localizedDescription)")
        if let recovery = error.recoverySuggestion {
            print("Recovery suggestion: \(recovery)")
        }
    }
}

// MARK: - Error Presenting

protocol ErrorPresenting {
    func present(_ error: AppError)
    func dismissError()
}

struct DefaultErrorPresenter: ErrorPresenting {
    func present(_ error: AppError) {
        // UI上でのエラー表示
        // 例：アラート表示など
    }
    
    func dismissError() {
        // エラー表示の消去
    }
}
