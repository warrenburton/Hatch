//
//  Created by Warren Burton on 27/03/2024.
//

import Foundation

/// Stores whether the function is throwing or not
public enum ThrowingStatus: String {
    case none
    case `throws`
    case `rethrows`
    case unknown
}
