import SwiftUI

extension EnvironmentValues {

    var dependency: DependencyType? {
        get { self[DependencyKey.self] }
        set { self[DependencyKey.self] = newValue }
    }
}

struct DependencyKey: EnvironmentKey {

    static var defaultValue: DependencyType? = nil
}
