import UIKit

actor WallColorManager {
    private var colorMap: [UUID: UIColor] = [:]
    private var nextColorIndex = 0
    
    private let colors: [UIColor] = [
        UIColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 0.5),
        UIColor(red: 0.0, green: 0.4, blue: 1.0, alpha: 0.5),
        UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.5),
        UIColor(red: 0.7, green: 0.0, blue: 1.0, alpha: 0.5),
        UIColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 0.5),
        UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.5),
        UIColor(red: 0.0, green: 0.7, blue: 0.7, alpha: 0.5),
        UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5),
        UIColor(red: 0.5, green: 0.8, blue: 0.0, alpha: 0.5),
        UIColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 0.5)
    ]
    
    func getColor(for groupID: UUID) async -> UIColor {
        return colorMap[groupID] ?? UIColor.gray
    }
    
    func assignColor(for groupID: UUID) async {
        colorMap[groupID] = colors[nextColorIndex % colors.count]
        nextColorIndex += 1
    }
    
    func releaseColor(for groupID: UUID) async {
        colorMap.removeValue(forKey: groupID)
    }
}
