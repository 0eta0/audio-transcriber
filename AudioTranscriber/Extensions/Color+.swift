import Foundation
import SwiftUI


extension Color {

    init?(_ hex: String, opacity: Double = 1.0) {
        let hexNorm = hex.hasPrefix("#") ? String(hex.dropFirst(1)) : hex
        let scanner = Scanner(string: hexNorm)
        var color: UInt64 = 0
        if scanner.scanHexInt64(&color) {
            let red = CGFloat((color & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((color & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat(color & 0x0000FF) / 255.0
            self.init(red: red, green: green, blue: blue, opacity: opacity)
        } else {
            return nil
        }
    }
}
