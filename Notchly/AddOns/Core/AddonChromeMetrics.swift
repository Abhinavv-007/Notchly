//
//  AddonChromeMetrics.swift
//  Notchly
//
//  Shared metrics used by the add-on layer to extend the collapsed notch
//  chrome just enough to contain the two circular side indicators.
//
//  The view hierarchy renders the indicators as an overlay above the
//  notch pill. They must sit immediately beside the pill, as if they
//  were part of the same island. These constants are the single source
//  of truth used by `NotchSideIndicatorsView`, the outside-click
//  monitor, and any future chrome reservation math.
//

import Foundation
import CoreGraphics

enum AddonChromeMetrics {
    /// Diameter of the circular indicator button.
    static let indicatorDiameter: CGFloat = 22

    /// Gap between the notch edge and the indicator.
    static let sideGap: CGFloat = 3

    /// Extra horizontal reserve on each side of the notch pill needed to
    /// fit one indicator + its gap + 2pt safety padding.
    static var sideReserve: CGFloat {
        indicatorDiameter + sideGap + 2
    }

    /// Total visible width of the indicator strip given the notch width.
    static func chromeWidth(forNotchWidth notchWidth: CGFloat) -> CGFloat {
        notchWidth + 2 * (indicatorDiameter + sideGap)
    }
}
