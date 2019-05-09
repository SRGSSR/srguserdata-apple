//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import DeepDiff
import SRGDataProvider
import SRGUserData
import UIKit

extension SRGMedia: DiffAware {
    public var diffId: Int {
        return self.urn.hashValue
    }
    
    public static func compareContent(_ a: SRGMedia, _ b: SRGMedia) -> Bool {
        return a.urn == b.urn
    }
}

extension SRGUserObject: DiffAware {
    public var diffId: Int {
        return self.uid.hashValue
    }
    
    public static func compareContent(_ a: SRGUserObject, _ b: SRGUserObject) -> Bool {
        return a.uid == b.uid
    }
}

extension UITableView {
    fileprivate func deepDiffReload<T>(old: [T], new: [T], section: Int = 0, updateData: () -> Void) where T : DiffAware {
        if !old.isEmpty && !new.isEmpty {
            let changes = diff(old: old, new: new)
            self.reload(changes: changes, section: section, insertionAnimation: .automatic, deletionAnimation: .automatic, replacementAnimation: .automatic, updateData: updateData, completion: nil)
        }
        else {
            updateData()
            self.reloadData()
        }
    }
    
    @objc public func deepDiffReloadMedias(oldMedias: [SRGMedia], newMedias: [SRGMedia], section: Int = 0, updateData: () -> Void) {
        return deepDiffReload(old: oldMedias, new: newMedias, updateData: updateData)
    }
    
    @objc public func deepDiffReloadUserObjects(oldObjects: [SRGUserObject], newObjects: [SRGUserObject], section: Int = 0, updateData: () -> Void) {
        return deepDiffReload(old: oldObjects, new: newObjects, updateData: updateData)
    }
}
