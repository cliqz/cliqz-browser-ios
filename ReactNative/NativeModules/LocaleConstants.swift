//
//  LocaleConstants.swift
//  Cliqz
//
//  Created by Krzysztof Modras on 29.08.19.
//  Copyright © 2019 Cliqz. All rights reserved.
//

import Foundation

@objc(LocaleConstants)
class LocaleConstants: NSObject {
    @objc
    func constantsToExport() -> [String: Any]! {
        return ["lang": Locale.current.languageCode ?? "en", "locale": Locale.current.identifier]
    }

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
}
