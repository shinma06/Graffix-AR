import UIKit

extension UIView {
    func findView<T: UIView>(of type: T.Type) -> T? {
        if let view = self as? T {
            return view
        }
        for subview in subviews {
            if let found = subview.findView(of: type) {
                return found
            }
        }
        return nil
    }
}
