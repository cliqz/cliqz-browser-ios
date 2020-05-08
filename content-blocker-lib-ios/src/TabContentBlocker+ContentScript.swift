/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import WebKit

extension TabContentBlocker {
    func clearPageStats() {
        self.stats = TPPageStats()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        guard (self.isAntiTrackingEnabled || self.isAdBlockingEnabled),
            let body = message.body as? [String: Any],
            let urls = body["urls"] as? [String],
            let mainDocumentUrl = tab?.currentURL() else {
            return
        }

        // Reset the pageStats to make sure the trackingprotection shield icon knows that a page was allowListed
        let isAdsAllowListed = !self.isAntiTrackingEnabled || ContentBlocker.shared.isAdsAllowListed(url: mainDocumentUrl)
        let isTrackingAllowListed = !self.isAdBlockingEnabled || ContentBlocker.shared.isTrackingAllowListed(url: mainDocumentUrl)
        guard !isAdsAllowListed || !isTrackingAllowListed else {
            clearPageStats()
            return
        }

        // The JS sends the urls in batches for better performance. Iterate the batch and check the urls.
        for urlString in urls {
            guard var components = URLComponents(string: urlString) else { return }
            components.scheme = "http"
            guard let url = components.url else { return }

            TPStatsBlocklistChecker.shared.isBlocked(url: url).uponQueue(.main) { tracker in
                guard let tracker = tracker else { return }
                self.stats.update(byAddingTracker: tracker)
            }
        }
    }
}
