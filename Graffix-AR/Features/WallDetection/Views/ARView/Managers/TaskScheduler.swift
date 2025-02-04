//import Foundation
//
//// MARK: - Protocols
//
//protocol TaskScheduling: AnyObject {
//    func startTask(identifier: String, interval: TimeInterval, operation: @escaping () async throws -> Void) async
//    func stopTask(identifier: String)
//    func stopAllTasks()
//}
//
//protocol TaskSchedulerDelegate: AnyObject {
//    func taskScheduler(_ scheduler: TaskScheduling, didFailWithError error: Error, inTask identifier: String) async
//}
//
//// MARK: - TaskScheduler Implementation
//
//actor TaskScheduler: TaskScheduling {
//    private var tasks: [String: Task<Void, Never>] = [:]
//    private weak var delegate: TaskSchedulerDelegate?
//    
//    init(delegate: TaskSchedulerDelegate?) {
//        self.delegate = delegate
//    }
//    
//    func startTask(identifier: String, interval: TimeInterval, operation: @escaping () async throws -> Void) async {
//        stopTask(identifier)
//        
//        tasks[identifier] = Task { [weak self] in
//            while !Task.isCancelled {
//                do {
//                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
//                    try await operation()
//                } catch {
//                    if !Task.isCancelled, let self = self {
//                        await self.delegate?.taskScheduler(self, didFailWithError: error, inTask: identifier)
//                    }
//                }
//            }
//        }
//    }
//    
//    func stopTask(identifier: String) {
//        tasks[identifier]?.cancel()
//        tasks.removeValue(forKey: identifier)
//    }
//    
//    func stopAllTasks() {
//        for task in tasks.values {
//            task.cancel()
//        }
//        tasks.removeAll()
//    }
//    
//    deinit {
//        stopAllTasks()
//    }
//}
//
//// MARK: - Task Identifiers
//
//extension TaskScheduler {
//    enum TaskIdentifier {
//        static let cleanup = "cleanup"
//        static let intersectionCheck = "intersectionCheck"
//        
//        static var all: [String] {
//            [cleanup, intersectionCheck]
//        }
//    }
//}
