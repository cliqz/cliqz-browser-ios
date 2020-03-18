//
// Copyright (c) 2017-2019 Cliqz GmbH. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import UIKit
import Shared

private let SectionHeaderFooterIdentifier = "SectionHeaderFooterIdentifier"

class TodayWidgetViewController: UIViewController {

    var profile: Profile!

    var tableView: UITableView!
    var searchController: UISearchController?

    private var cities: [String]!
    private var searchResult: [String]!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.getCities()
        self.title = Strings.Settings.TodayWidget.Title
        self.navigationController?.setToolbarHidden(true, animated: false)

        self.tableView = UITableView()
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.separatorColor = Theme.tableView.separator
        self.tableView.backgroundColor = Theme.tableView.headerBackground

        let footer = ThemedTableSectionHeaderFooterView(frame: CGRect(width: self.tableView.bounds.width, height: SettingsUX.TableViewHeaderFooterHeight))
        footer.showBottomBorder = false
        tableView.tableFooterView = footer

        self.view.addSubview(self.tableView)

        self.tableView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }

        let searchController = UISearchController(searchResultsController: nil)

        // No need to hide the navigation bar on iPad, on iPhone the additional height is useful.
        searchController.hidesNavigationBarDuringPresentation = !UIDevice.current.isPad

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = Strings.Settings.TodayWidget.SearchLabel

        self.navigationItem.searchController = searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.searchController = searchController

        self.definesPresentationContext = true
    }

    // MARK: - Private methods

    private func getCities() {
        self.cities = ["Munich", "Berlin", "Humburg", "Frankfurt", "Boon", "Bremen", "Dresden", "Nuremberg", "Leipzig", "Stuttgart", "Cologne", "Dortmund", "Hanover"]
    }

}

extension TodayWidgetViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = ThemedTableViewCell(style: .default, reuseIdentifier: nil)
        let cityName = self.searchResult[indexPath.row]
        cell.titleLabel.text = cityName
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.searchResult?.count ?? 0
    }
}

extension TodayWidgetViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cityName = self.searchResult[indexPath.row]
        self.profile.prefs.setString(cityName, forKey: PrefsKeys.TodayWidgetWeatherLocation)
        tableView.deselectRow(at: indexPath, animated: false)
        self.navigationController?.popViewController(animated: true)
    }

}

extension TodayWidgetViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let search: String = searchController.searchBar.text ?? ""
        self.searchResult = search.count > 2 ? self.cities.filter({ $0.lowercased().contains(search.lowercased()) }) : nil
        self.tableView.reloadData()
    }

}
