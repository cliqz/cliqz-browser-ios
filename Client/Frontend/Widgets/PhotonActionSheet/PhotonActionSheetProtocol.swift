/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import Storage

protocol PhotonActionSheetProtocol {
    var tabManager: TabManager { get }
    var profile: Profile { get }
}

private let log = Logger.browserLogger

extension PhotonActionSheetProtocol {
    typealias PresentableVC = UIViewController & UIPopoverPresentationControllerDelegate
    typealias MenuAction = () -> Void
    typealias IsPrivateTab = Bool
    typealias URLOpenAction = (URL?, IsPrivateTab) -> Void

    func presentSheetWith(title: String? = nil, actions: [[PhotonActionSheetItem]], on viewController: PresentableVC, from view: UIView, closeButtonTitle: String = Strings.CloseButtonTitle, suppressPopover: Bool = false) {
        let style: UIModalPresentationStyle = (UIDevice.current.userInterfaceIdiom == .pad && !suppressPopover) ? .popover : .overCurrentContext
        let sheet = PhotonActionSheet(title: title, actions: actions, closeButtonTitle: closeButtonTitle, style: style)
        sheet.modalPresentationStyle = style
        sheet.photonTransitionDelegate = PhotonActionSheetAnimator()

        if let popoverVC = sheet.popoverPresentationController, sheet.modalPresentationStyle == .popover {
            popoverVC.delegate = viewController
            popoverVC.sourceView = view
            popoverVC.sourceRect = CGRect(x: view.frame.width/2, y: view.frame.size.height * 0.75, width: 1, height: 1)
            popoverVC.permittedArrowDirections = .up
        }
        viewController.present(sheet, animated: true, completion: nil)
    }

    //Returns a list of actions which is used to build a menu
    //OpenURL is a closure that can open a given URL in some view controller. It is up to the class using the menu to know how to open it
    func getLibraryActions(vcDelegate: PageOptionsVC) -> [PhotonActionSheetItem] {
        guard let tab = self.tabManager.selectedTab else { return [] }

        let openLibrary = PhotonActionSheetItem(title: Strings.AppMenuLibraryTitleString, iconString: "menu-library") { action in
            let bvc = vcDelegate as? BrowserViewController
            bvc?.showLibrary()
        }

        let openHomePage = PhotonActionSheetItem(title: Strings.AppMenuOpenHomePageTitleString, iconString: "menu-Home") { _ in
            let page = NewTabAccessors.getHomePage(self.profile.prefs)
            if page == .homePage, let homePageURL = HomeButtonHomePageAccessors.getHomePage(self.profile.prefs) {
                tab.loadRequest(PrivilegedRequest(url: homePageURL) as URLRequest)
            } else if let homePanelURL = page.url {
                tab.loadRequest(PrivilegedRequest(url: homePanelURL) as URLRequest)
            }
        }

        return [openHomePage, openLibrary]
    }

    /*
     Returns a list of actions which is used to build the general browser menu
     These items repersent global options that are presented in the menu
     TODO: These icons should all have the icons and use Strings.swift
     */

    typealias PageOptionsVC = SettingsDelegate & PresentingModalViewControllerDelegate & UIViewController

    func getOtherPanelActions(vcDelegate: PageOptionsVC) -> [PhotonActionSheetItem] {
        var items: [PhotonActionSheetItem] = []

        let noImageEnabled = NoImageModeHelper.isActivated(profile.prefs)
        let noImageMode = PhotonActionSheetItem(title: Strings.AppMenuNoImageMode, iconString: "menu-NoImageMode", isEnabled: noImageEnabled, accessory: .Switch, badgeIconNamed: "menuBadge") { action in
            NoImageModeHelper.toggle(isEnabled: action.isEnabled, profile: self.profile, tabManager: self.tabManager)
        }

        let trackingProtectionEnabled = FirefoxTabContentBlocker.isTrackingProtectionEnabled(tabManager: self.tabManager)
        let trackingProtection = PhotonActionSheetItem(title: Strings.TPMenuTitle, iconString: "menu-TrackingProtection", isEnabled: trackingProtectionEnabled, accessory: .Switch) { action in
            FirefoxTabContentBlocker.toggleTrackingProtectionEnabled(prefs: self.profile.prefs, tabManager: self.tabManager)
        }
        items.append(contentsOf: [trackingProtection, noImageMode])

        let nightModeEnabled = NightModeHelper.isActivated(profile.prefs)
        let nightMode = PhotonActionSheetItem(title: Strings.AppMenuNightMode, iconString: "menu-NightMode", isEnabled: nightModeEnabled, accessory: .Switch) { action in
            NightModeHelper.toggle(self.profile.prefs, tabManager: self.tabManager)
            // If we've enabled night mode and the theme is normal, enable dark theme
            if NightModeHelper.isActivated(self.profile.prefs), ThemeManager.instance.currentName == .normal {
                ThemeManager.instance.current = DarkTheme()
                NightModeHelper.setEnabledDarkTheme(self.profile.prefs, darkTheme: true)
            }
            // If we've disabled night mode and dark theme was activated by it then disable dark theme
            if !NightModeHelper.isActivated(self.profile.prefs), NightModeHelper.hasEnabledDarkTheme(self.profile.prefs), ThemeManager.instance.currentName == .dark {
                ThemeManager.instance.current = NormalTheme()
                NightModeHelper.setEnabledDarkTheme(self.profile.prefs, darkTheme: false)
            }
        }
        items.append(nightMode)

        let openSettings = PhotonActionSheetItem(title: Strings.AppMenuSettingsTitleString, iconString: "menu-Settings") { action in
            let settingsTableViewController = AppSettingsTableViewController()
            settingsTableViewController.profile = self.profile
            settingsTableViewController.tabManager = self.tabManager
            settingsTableViewController.settingsDelegate = vcDelegate

            let controller = ThemedNavigationController(rootViewController: settingsTableViewController)
            controller.presentingModalViewControllerDelegate = vcDelegate

            // Wait to present VC in an async dispatch queue to prevent a case where dismissal
            // of this popover on iPad seems to block the presentation of the modal VC.
            DispatchQueue.main.async {
                vcDelegate.present(controller, animated: true, completion: nil)
            }
        }
        items.append(openSettings)

        return items
    }

    fileprivate func shareFileURL(url: URL, file: URL?, buttonView: UIView, presentableVC: PresentableVC) {
        let helper = ShareExtensionHelper(url: url, file: file, tab: nil)
        let controller = helper.createActivityViewController { completed, activityType in
            print("Shared downloaded file: \(completed)")
        }

        if let popoverPresentationController = controller.popoverPresentationController {
            popoverPresentationController.sourceView = buttonView
            popoverPresentationController.sourceRect = buttonView.bounds
            popoverPresentationController.permittedArrowDirections = .up
        }

        presentableVC.present(controller, animated: true, completion: nil)
    }

    func getTabActions(tab: Tab, buttonView: UIView,
                       presentShareMenu: @escaping (URL, Tab, UIView, UIPopoverArrowDirection) -> Void,
                       findInPage:  @escaping () -> Void,
                       presentableVC: PresentableVC,
                       isBookmarked: Bool,
                       isPinned: Bool,
                       success: @escaping (String) -> Void) -> Array<[PhotonActionSheetItem]> {
        if tab.url?.isFileURL ?? false {
            let shareFile = PhotonActionSheetItem(title: Strings.AppMenuSharePageTitleString, iconString: "action_share") { action in
                guard let url = tab.url else { return }

                self.shareFileURL(url: url, file: nil, buttonView: buttonView, presentableVC: presentableVC)
            }

            return [[shareFile]]
        }

        let toggleActionTitle = tab.desktopSite ? Strings.AppMenuViewMobileSiteTitleString : Strings.AppMenuViewDesktopSiteTitleString
        let toggleDesktopSite = PhotonActionSheetItem(title: toggleActionTitle, iconString: "menu-RequestDesktopSite", isEnabled: tab.desktopSite, badgeIconNamed: "menuBadge") { action in
            if let url = tab.url {
                tab.toggleDesktopSite()
                Tab.DesktopSites.updateDomainList(forUrl: url, isDesktopSite: tab.desktopSite, isPrivate: tab.isPrivate)
            }
        }

        let addReadingList = PhotonActionSheetItem(title: Strings.AppMenuAddToReadingListTitleString, iconString: "addToReadingList") { action in
            guard let url = tab.url?.displayURL else { return }

            self.profile.readingList.createRecordWithURL(url.absoluteString, title: tab.title ?? "", addedBy: UIDevice.current.name)
            success(Strings.AppMenuAddToReadingListConfirmMessage)
        }

        let bookmarkPage = PhotonActionSheetItem(title: Strings.AppMenuAddBookmarkTitleString, iconString: "menu-Bookmark") { action in
            guard let url = tab.canonicalURL?.displayURL,
                let bvc = presentableVC as? BrowserViewController else {
                return
            }
            bvc.addBookmark(url: url.absoluteString, title: tab.title, favicon: tab.displayFavicon)
            success(Strings.AppMenuAddBookmarkConfirmMessage)
        }

        let removeBookmark = PhotonActionSheetItem(title: Strings.AppMenuRemoveBookmarkTitleString, iconString: "menu-Bookmark-Remove") { action in
            guard let url = tab.url?.displayURL else { return }

            self.profile.places.deleteBookmarksWithURL(url: url.absoluteString).uponQueue(.main) { result in
                if result.isSuccess {
                    success(Strings.AppMenuRemoveBookmarkConfirmMessage)
                }
            }
        }

        let pinToTopSites = PhotonActionSheetItem(title: Strings.PinTopsiteActionTitle, iconString: "action_pin") { action in
            guard let url = tab.url?.displayURL, let sql = self.profile.history as? SQLiteHistory else { return }

            sql.getSites(forURLs: [url.absoluteString]).bind { val -> Success in
                guard let site = val.successValue?.asArray().first?.flatMap({ $0 }) else {
                    return succeed()
                }

                return self.profile.history.addPinnedTopSite(site)
            }.uponQueue(.main) { _ in }
        }

        let removeTopSitesPin = PhotonActionSheetItem(title: Strings.RemovePinTopsiteActionTitle, iconString: "action_unpin") { action in
            guard let url = tab.url?.displayURL, let sql = self.profile.history as? SQLiteHistory else { return }

            sql.getSites(forURLs: [url.absoluteString]).bind { val -> Success in
                guard let site = val.successValue?.asArray().first?.flatMap({ $0 }) else {
                    return succeed()
                }

                return self.profile.history.removeFromPinnedTopSites(site)
            }.uponQueue(.main) { _ in }
        }

        let sharePage = PhotonActionSheetItem(title: Strings.AppMenuSharePageTitleString, iconString: "action_share") { action in
            guard let url = tab.canonicalURL?.displayURL else { return }

            if let temporaryDocument = tab.temporaryDocument {
                temporaryDocument.getURL().uponQueue(.main, block: { tempDocURL in
                    // If we successfully got a temp file URL, share it like a downloaded file,
                    // otherwise present the ordinary share menu for the web URL.
                    if tempDocURL.isFileURL {
                        self.shareFileURL(url: url, file: tempDocURL, buttonView: buttonView, presentableVC: presentableVC)
                    } else {
                        presentShareMenu(url, tab, buttonView, .up)
                    }
                })
            } else {
                presentShareMenu(url, tab, buttonView, .up)
            }
        }

        let copyURL = PhotonActionSheetItem(title: Strings.AppMenuCopyURLTitleString, iconString: "menu-Copy-Link") { _ in
            if let url = tab.canonicalURL?.displayURL {
                UIPasteboard.general.url = url
                success(Strings.AppMenuCopyURLConfirmMessage)
            }
        }

        var mainActions = [sharePage]

        // Disable bookmarking and reading list if the URL is too long.
        if !tab.urlIsTooLong {
            mainActions.append(isBookmarked ? removeBookmark : bookmarkPage)

            if tab.readerModeAvailableOrActive {
                mainActions.append(addReadingList)
            }
        }

        mainActions.append(contentsOf: [copyURL])

        let pinAction = (isPinned ? removeTopSitesPin : pinToTopSites)
        var commonActions = [toggleDesktopSite, pinAction]

        // Disable find in page if document is pdf.
        if tab.mimeType != MIMEType.PDF {
            let findInPageAction = PhotonActionSheetItem(title: Strings.AppMenuFindInPageTitleString, iconString: "menu-FindInPage") { action in
                findInPage()
            }
            commonActions.insert(findInPageAction, at: 0)
        }

        return [mainActions, commonActions]
    }

    func fetchBookmarkStatus(for url: String) -> Deferred<Maybe<Bool>> {
        return profile.places.isBookmarked(url: url)
    }

    func fetchPinnedTopSiteStatus(for url: String) -> Deferred<Maybe<Bool>> {
        return self.profile.history.isPinnedTopSite(url)
    }

    func getLongPressLocationBarActions(with urlBar: URLBarView) -> [PhotonActionSheetItem] {
        let pasteGoAction = PhotonActionSheetItem(title: Strings.PasteAndGoTitle, iconString: "menu-PasteAndGo") { action in
            if let pasteboardContents = UIPasteboard.general.string {
                urlBar.delegate?.urlBar(urlBar, didSubmitText: pasteboardContents)
            }
        }
        let pasteAction = PhotonActionSheetItem(title: Strings.PasteTitle, iconString: "menu-Paste") { action in
            if let pasteboardContents = UIPasteboard.general.string {
                urlBar.enterOverlayMode(pasteboardContents, pasted: true, search: true)
            }
        }
        let copyAddressAction = PhotonActionSheetItem(title: Strings.CopyAddressTitle, iconString: "menu-Copy-Link") { action in
            if let url = self.tabManager.selectedTab?.canonicalURL?.displayURL ?? urlBar.currentURL {
                UIPasteboard.general.url = url
            }
        }
        if UIPasteboard.general.string != nil {
            return [pasteGoAction, pasteAction, copyAddressAction]
        } else {
            return [copyAddressAction]
        }
    }

    @available(iOS 11.0, *)
    private func menuActionsForNotBlocking() -> [PhotonActionSheetItem] {
        return [PhotonActionSheetItem(title: Strings.SettingsTrackingProtectionSectionName, text: Strings.TPNoBlockingDescription, iconString: "menu-TrackingProtection")]
    }

    @available(iOS 11.0, *)
    private func menuActionsForTrackingProtectionDisabled(for tab: Tab) -> [[PhotonActionSheetItem]] {
        let enableTP = PhotonActionSheetItem(title: Strings.EnableTPBlocking, iconString: "menu-TrackingProtection") { _ in
            // When TP is off for the tab tapping enable in this menu should turn it back on for the Tab.
            if let blocker = tab.contentBlocker, blocker.isUserEnabled == false {
                blocker.isUserEnabled = true
            } else {
                FirefoxTabContentBlocker.toggleTrackingProtectionEnabled(prefs: self.profile.prefs, tabManager: self.tabManager)
            }
            tab.reload()
        }

        let moreInfo = PhotonActionSheetItem(title: Strings.TPBlockingMoreInfo, iconString: "menu-Info") { _ in
            let url = SupportUtils.URLForTopic("tracking-protection-ios")!
            tab.loadRequest(PrivilegedRequest(url: url) as URLRequest)
        }
        return [[moreInfo], [enableTP]]
    }

    @available(iOS 11.0, *)
    private func menuActionsForTrackingProtectionEnabled(for tab: Tab) -> [[PhotonActionSheetItem]] {
        guard let blocker = tab.contentBlocker, let currentURL = tab.url else {
            return []
        }

        let stats = blocker.stats
        let totalCount = PhotonActionSheetItem(title: Strings.TrackingProtectionTotalBlocked, accessory: .Text, accessoryText: "\(stats.total)", bold: true)
        let adCount = PhotonActionSheetItem(title: Strings.TrackingProtectionAdsBlocked, accessory: .Text, accessoryText: "\(stats.adCount)")
        let analyticsCount = PhotonActionSheetItem(title: Strings.TrackingProtectionAnalyticsBlocked, accessory: .Text, accessoryText: "\(stats.analyticCount)")
        let socialCount = PhotonActionSheetItem(title: Strings.TrackingProtectionSocialBlocked, accessory: .Text, accessoryText: "\(stats.socialCount)")
        let contentCount = PhotonActionSheetItem(title: Strings.TrackingProtectionContentBlocked, accessory: .Text, accessoryText: "\(stats.contentCount)")
        let statList = [totalCount, adCount, analyticsCount, socialCount, contentCount]

        let addToWhitelist = PhotonActionSheetItem(title: Strings.TrackingProtectionDisableTitle, iconString: "menu-TrackingProtection-Off") { _ in
            ContentBlocker.shared.whitelist(enable: true, url: currentURL) {
                tab.reload()
            }
        }
        return [statList, [addToWhitelist]]
    }

    @available(iOS 11.0, *)
    private func menuActionsForWhitelistedSite(for tab: Tab) -> [[PhotonActionSheetItem]] {
        guard let currentURL = tab.url else {
            return []
        }

        let removeFromWhitelist = PhotonActionSheetItem(title: Strings.TrackingProtectionWhiteListRemove, iconString: "menu-TrackingProtection") { _ in
            ContentBlocker.shared.whitelist(enable: false, url: currentURL) {
                tab.reload()
            }
        }
        return [[removeFromWhitelist]]
    }

    @available(iOS 11.0, *)
    func getTrackingMenu(for tab: Tab, presentingOn urlBar: URLBarView) -> [PhotonActionSheetItem] {
        guard let blocker = tab.contentBlocker else {
            return []
        }

        switch blocker.status {
        case .NoBlockedURLs:
            return menuActionsForNotBlocking()
        case .Blocking:
            let actions = menuActionsForTrackingProtectionEnabled(for: tab)
            let tpBlocking = PhotonActionSheetItem(title: Strings.SettingsTrackingProtectionSectionName, text: Strings.TPBlockingDescription, iconString: "menu-TrackingProtection", isEnabled: false, accessory: .Disclosure) { _ in
                guard let bvc = self as? PresentableVC else { return }
                self.presentSheetWith(title: Strings.SettingsTrackingProtectionSectionName, actions: actions, on: bvc, from: urlBar)
            }
            return [tpBlocking]
        case .Disabled:
            let actions = menuActionsForTrackingProtectionDisabled(for: tab)
            let tpBlocking = PhotonActionSheetItem(title: Strings.SettingsTrackingProtectionSectionName, text: Strings.TPBlockingDisabledDescription, iconString: "menu-TrackingProtection", isEnabled: false, accessory: .Disclosure) { _ in
                guard let bvc = self as? PresentableVC else { return }
                self.presentSheetWith(title: Strings.SettingsTrackingProtectionSectionName, actions: actions, on: bvc, from: urlBar)
            }
            return  [tpBlocking]
        case .Whitelisted:
            let actions = self.menuActionsForWhitelistedSite(for: tab)
            let tpBlocking = PhotonActionSheetItem(title: Strings.SettingsTrackingProtectionSectionName, text: Strings.TrackingProtectionWhiteListOn, iconString: "menu-TrackingProtection-Off", isEnabled: false, accessory: .Disclosure) { _ in
                guard let bvc = self as? PresentableVC else { return }
                self.presentSheetWith(title: Strings.SettingsTrackingProtectionSectionName, actions: actions, on: bvc, from: urlBar)
            }
            return [tpBlocking]
        }
    }

    @available(iOS 11.0, *)
    func getTrackingSubMenu(for tab: Tab) -> [[PhotonActionSheetItem]] {
        guard let blocker = tab.contentBlocker else {
            return []
        }
        switch blocker.status {
        case .NoBlockedURLs:
            return []
        case .Blocking:
            return menuActionsForTrackingProtectionEnabled(for: tab)
        case .Disabled:
            return menuActionsForTrackingProtectionDisabled(for: tab)
        case .Whitelisted:
            return menuActionsForWhitelistedSite(for: tab)
        }
    }

    func getRefreshLongPressMenu(for tab: Tab) -> [PhotonActionSheetItem] {
        guard tab.webView?.url != nil && (tab.getContentScript(name: ReaderMode.name()) as? ReaderMode)?.state != .active else {
            return []
        }

        let toggleActionTitle = tab.desktopSite ? Strings.AppMenuViewMobileSiteTitleString : Strings.AppMenuViewDesktopSiteTitleString
        let toggleDesktopSite = PhotonActionSheetItem(title: toggleActionTitle, iconString: "menu-RequestDesktopSite") { action in

            if let url = tab.url {
                tab.toggleDesktopSite()
                Tab.DesktopSites.updateDomainList(forUrl: url, isDesktopSite: tab.desktopSite, isPrivate: tab.isPrivate)
            }
        }

        if let helper = tab.contentBlocker {
            let title = helper.isEnabled ? Strings.TrackingProtectionReloadWithout : Strings.TrackingProtectionReloadWith
            let imageName = helper.isEnabled ? "menu-TrackingProtection-Off" : "menu-TrackingProtection"
            let toggleTP = PhotonActionSheetItem(title: title, iconString: imageName) { action in
                helper.isUserEnabled = !helper.isEnabled
            }
            return [toggleDesktopSite, toggleTP]
        } else {
            return [toggleDesktopSite]
        }
    }
}
