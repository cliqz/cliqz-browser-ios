/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared

/// App Settings Screen (triggered by tapping the 'Gear' in the Tab Tray Controller)
class AppSettingsTableViewController: SettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Settings", comment: "Title in the settings view controller title bar")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Done", comment: "Done button on left side of the Settings view controller title bar"),
            style: .done,
            target: navigationController, action: #selector((navigationController as! ThemedNavigationController).done))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "AppSettingsTableViewController.navigationItem.leftBarButtonItem"

        tableView.accessibilityIdentifier = "AppSettingsTableViewController.tableView"

    }

    override func generateSettings() -> [SettingSection] {
        var settings = [SettingSection]()

        let privacyTitle = NSLocalizedString("Privacy", comment: "Privacy section title")

        let prefs = profile.prefs
        var generalSettings: [Setting] = [
            SearchSetting(settings: self),
            OpenWithSetting(settings: self),
            BoolSetting(prefs: prefs, prefKey: "blockPopups", defaultValue: true,
                        titleText: NSLocalizedString("Block Pop-up Windows", comment: "Block pop-up windows setting")),
           ]

        if #available(iOS 12.0, *) {
            generalSettings.insert(SiriPageSetting(settings: self), at: 2)
        }

        // There is nothing to show in the Customize section if we don't include the compact tab layout
        // setting on iPad. When more options are added that work on both device types, this logic can
        // be changed.

        generalSettings += [
            BoolSetting(prefs: prefs, prefKey: "showClipboardBar", defaultValue: false,
                        titleText: Strings.SettingsOfferClipboardBarTitle,
                        statusText: Strings.SettingsOfferClipboardBarStatus),
        ]

        settings += [ SettingSection(title: NSAttributedString(string: Strings.SettingsGeneralSectionTitle), children: generalSettings)]

        var privacySettings = [Setting]()

        privacySettings.append(ClearPrivateDataSetting(settings: self))

        privacySettings += [
            BoolSetting(prefs: prefs,
                prefKey: "settings.closePrivateTabs",
                defaultValue: false,
                titleText: NSLocalizedString("Close Private Tabs", tableName: "PrivateBrowsing", comment: "Setting for closing private tabs"),
                statusText: NSLocalizedString("When Leaving Private Browsing", tableName: "PrivateBrowsing", comment: "Will be displayed in Settings under 'Close Private Tabs'")),
        ]

        privacySettings.append(ContentBlockerSetting(settings: self))

        privacySettings += [
            PrivacyPolicySetting(),
        ]

        settings += [
            SettingSection(title: NSAttributedString(string: privacyTitle), children: privacySettings),
            SettingSection(title: NSAttributedString(string: NSLocalizedString("Support", comment: "Support section title")), children: [
                ShowIntroductionSetting(settings: self),
                SendFeedbackSetting(),
                SendAnonymousUsageDataSetting(prefs: prefs, delegate: settingsDelegate),
                OpenSupportPageSetting(delegate: settingsDelegate),
            ]),
            SettingSection(title: NSAttributedString(string: NSLocalizedString("About", comment: "About settings section title")), children: [
                VersionSetting(settings: self),
                LicenseAndAcknowledgementsSetting(),
                YourRightsSetting(),
                ExportBrowserDataSetting(settings: self),
                ExportLogDataSetting(settings: self),
                DeleteExportedDataSetting(settings: self),
                ForceCrashSetting(settings: self),
                SlowTheDatabase(settings: self),
                SentryIDSetting(settings: self),
            ]), ]

        return settings
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = super.tableView(tableView, viewForHeaderInSection: section) as! ThemedTableSectionHeaderFooterView
        // Prevent the top border from showing for the General section.
        switch section {
        case 1:
            headerView.showTopBorder = false
        default:
            break
        }

        return headerView
    }
}
