//
// Copyright (c) 2017-2019 Cliqz GmbH. All rights reserved.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Shared
import Storage
import UIKit

// MARK: - Placeholder strings for Bug 1232810.
let deleteWarningTitle = NSLocalizedString("This folder isn’t empty.", tableName: "BookmarkPanelDeleteConfirm", comment: "Title of the confirmation alert when the user tries to delete a folder that still contains bookmarks and/or folders.")
let deleteWarningDescription = NSLocalizedString("Are you sure you want to delete it and its contents?", tableName: "BookmarkPanelDeleteConfirm", comment: "Main body of the confirmation alert when the user tries to delete a folder that still contains bookmarks and/or folders.")
let deleteCancelButtonLabel = NSLocalizedString("Cancel", tableName: "BookmarkPanelDeleteConfirm", comment: "Button label to cancel deletion when the user tried to delete a non-empty folder.")
let deleteDeleteButtonLabel = NSLocalizedString("Delete", tableName: "BookmarkPanelDeleteConfirm", comment: "Button label for the button that deletes a folder and all of its children.")

// Placeholder strings for Bug 1248034
let emptyBookmarksText = NSLocalizedString("Bookmarks you save will show up here.", comment: "Status label for the empty Bookmarks state.")

class BookmarksView: LibraryView {
    // MARK: - UX constants.
    private struct BookmarksPanelUX {
        static let BookmarkFolderHeaderViewChevronInset: CGFloat = 10
        static let BookmarkFolderChevronSize: CGFloat = 20
        static let BookmarkFolderChevronLineWidth: CGFloat = 2.0
        static let WelcomeScreenPadding: CGFloat = 15
        static let WelcomeScreenItemWidth = 170
        static let SeparatorRowHeight: CGFloat = 0.5
        static let IconSize: CGFloat = 23
        static let IconBorderWidth: CGFloat = 0.5
        static let IconBorderColor = UIColor.Grey30
    }

    // MARK: - Properties
    var source: BookmarksModel?
    var parentFolders = [BookmarkFolder]()
    var bookmarkFolder: BookmarkFolder?
    var refreshControl: UIRefreshControl?

    private lazy var emptyStateOverlayView: UIView = self.createEmptyStateOverlayView()

    private let BookmarkFolderCellIdentifier = "BookmarkFolderIdentifier"
    private let BookmarkSeparatorCellIdentifier = "BookmarkSeparatorIdentifier"
    private let BookmarkFolderHeaderViewIdentifier = "BookmarkFolderHeaderIdentifier"

    // MARK: - Initialization
    override func setup() {
        super.setup()
        self.tableView.accessibilityIdentifier = Strings.BookmarksTitle
        self.tableView.addGestureRecognizer(self.longPressRecognizer)
        self.loadData()
    }

    override func applyTheme() {
        super.applyTheme()
    }

    // MARK: - Public API
    override func siteForIndexPath(_ indexPath: IndexPath) -> Site? {
        guard let source = source, let bookmark = source.current[indexPath.row] else { return nil }

        switch bookmark {
        case let item as BookmarkItem:
            return Site(url: item.url, title: item.title, bookmarked: true, guid: item.guid)
        case is BookmarkSeparator:
            return Site(url: "", title: "—", bookmarked: false)
        case is BookmarkFolder:
            return Site(url: "", title: "Folder", bookmarked: false)
        default:
            // This should never happen, said the bishop to the actress
            break
        }

        return nil
    }

    override func removeSiteForURLAtIndexPath(_ indexPath: IndexPath) {
        guard let source = source, let bookmark = source.current[indexPath.row] else {
            print("Source not set, aborting.")
            return
        }

        // Don't delete folders, we don't create them anyway
        guard !(bookmark is BookmarkFolder) else { return }

        // Block to do this -- this is UI code.
        guard let factory = source.modelFactory.value.successValue else {
            print("Couldn't get model factory. This is unexpected.")
            self.onModelFailure(DatabaseError(description: "Unable to get factory."))
            return
        }

        let specificFactory = factory.factoryForIndex(indexPath.row, inFolder: source.current)
        if let err = specificFactory.removeByGUID(bookmark.guid).value.failureValue {
            print("Failed to remove \(bookmark.guid).")
            self.onModelFailure(err)
            return
        }

        self.tableView.beginUpdates()
        self.source = source.removeGUIDFromCurrent(bookmark.guid)
        self.tableView.deleteRows(at: [indexPath], with: .left)
        self.tableView.endUpdates()
        self.updateEmptyPanelState()
    }

    override func pinToTopSites(_ site: Site) {
        _ = self.profile.history.addPinnedTopSite(site).value
    }

    override func reloadData() {
        self.source?.reloadData().upon(onModelFetched)
    }

    func loadData() {
        // If we've not already set a source for this panel, fetch a new model from
        // the root; otherwise, just use the existing source to select a folder.
        guard let source = self.source else {
            // Get all the bookmarks split by folders
            if let bookmarkFolder = bookmarkFolder {
                profile.bookmarks.modelFactory >>== { $0.modelForFolder(bookmarkFolder).upon(self.onModelFetched) }
            } else {
                profile.bookmarks.modelFactory >>== { $0.modelForRoot().upon(self.onModelFetched) }
            }
            return
        }

        if let bookmarkFolder = bookmarkFolder {
            source.selectFolder(bookmarkFolder).upon(onModelFetched)
        } else {
            source.selectFolder(BookmarkRoots.MobileFolderGUID).upon(onModelFetched)
        }
    }

    private func onModelFetched(_ result: Maybe<BookmarksModel>) {
        guard let model = result.successValue else {
            self.onModelFailure(result.failureValue as Any)
            return
        }
        self.onNewModel(model)
    }

    private func onNewModel(_ model: BookmarksModel) {
        if Thread.current.isMainThread {
            self.source = model
            self.tableView.reloadData()
            return
        }

        DispatchQueue.main.async {
            self.source = model
            self.tableView.reloadData()
            self.updateEmptyPanelState()
        }
    }

    private func onModelFailure(_ e: Any) {
        print("Error: failed to get data: \(e)")
    }

}

// MARK: - Private API
private extension BookmarksView {
    private func updateEmptyPanelState() {
        // swiftlint:disable:next empty_count
        if source?.current.count == 0 && source?.current.guid == BookmarkRoots.MobileFolderGUID {
            if self.emptyStateOverlayView.superview == nil {
                self.addSubview(self.emptyStateOverlayView)
                self.bringSubviewToFront(self.emptyStateOverlayView)
                self.emptyStateOverlayView.snp.makeConstraints { make -> Void in
                    make.edges.equalTo(self.tableView)
                }
            }
        } else {
            self.emptyStateOverlayView.removeFromSuperview()
        }
    }

    private func createEmptyStateOverlayView() -> UIView {
        let overlayView = UIView()

        let logoImageView = UIImageView(image: UIImage.templateImageNamed("emptyBookmarks"))
        //        logoImageView.tintColor = UIColor.Photon.Grey60
        overlayView.addSubview(logoImageView)
        logoImageView.snp.makeConstraints { make in
            make.centerX.equalTo(overlayView)
            make.size.equalTo(60)
            // Sets proper top constraint for iPhone 6 in portait and for iPad.
            //            make.centerY.equalTo(overlayView).offset(HomePanelUX.EmptyTabContentOffset).priority(100)
            // Sets proper top constraint for iPhone 4, 5 in portrait.
            make.top.greaterThanOrEqualTo(overlayView).offset(50)
        }

        let welcomeLabel = UILabel()
        overlayView.addSubview(welcomeLabel)
        welcomeLabel.text = emptyBookmarksText
        welcomeLabel.textAlignment = .center
        welcomeLabel.font = DynamicFontHelper.defaultHelper.DeviceFontLight
        welcomeLabel.numberOfLines = 0
        welcomeLabel.adjustsFontSizeToFitWidth = true

        welcomeLabel.snp.makeConstraints { make in
            make.centerX.equalTo(overlayView)
            make.top.equalTo(logoImageView.snp.bottom).offset(BookmarksPanelUX.WelcomeScreenPadding)
            make.width.equalTo(BookmarksPanelUX.WelcomeScreenItemWidth)
        }

        overlayView.backgroundColor = UIColor.theme.homePanel.panelBackground
        welcomeLabel.textColor = UIColor.theme.homePanel.welcomeScreenText

        return overlayView
    }
}

// MARK: - Table View Data Source
extension BookmarksView {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return source?.current.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.accessoryType = .none
        return self.configureSite(cell, for: indexPath)
    }

    private func configureSite(_ cell: UITableViewCell, for indexPath: IndexPath) -> UITableViewCell {
        if let site = self.siteForIndexPath(indexPath), let cell = cell as? TwoLineTableViewCell {
            cell.setLines(site.title, detailText: site.url)
            cell.imageView?.layer.borderColor = BookmarksPanelUX.IconBorderColor.cgColor
            cell.imageView?.layer.borderWidth = BookmarksPanelUX.IconBorderWidth
            cell.imageView?.setIcon(site.icon, forURL: site.tileURL, completed: { (color, url) in
                if site.tileURL == url {
                    cell.imageView?.image = cell.imageView?.image?.createScaled(CGSize(width: BookmarksPanelUX.IconSize, height: BookmarksPanelUX.IconSize))
                    cell.imageView?.backgroundColor = color
                    cell.imageView?.contentMode = .center
                }
            })
        }
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Strings.BookmarksTitle
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let title = NSLocalizedString("Delete", tableName: "HistoryPanel", comment: "Action button for deleting history entries in the history panel.")
        let delete = UITableViewRowAction(style: .default, title: title, handler: { (action, indexPath) in
            self.removeSiteForURLAtIndexPath(indexPath)
        })
        return [delete]
    }
}