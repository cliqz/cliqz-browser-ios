//
// Copyright (c) 2017-2020 Cliqz GmbH. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation

public struct Features {
    public struct Search {
        public enum KeyboardReturnKeyBehavior {
            case dismiss
            case search
        }
        public struct AdditionalSearchEngines {
            public static var isEnabled: Bool {
                return true
            }
        }
        public static var keyboardReturnKeyBehavior: KeyboardReturnKeyBehavior {
            return .dismiss
        }
    }
    public struct PrivacyDashboard {
        public static var isAntiTrackingEnabled: Bool {
            return true
        }
        public static var isAdBlockingEnabled: Bool {
            return true
        }
        public static var isPopupBlockerEnabled: Bool {
            return true
        }
        public static var defaultEngineName: String {
            get {
                return ""
            }
        }
    }

}
