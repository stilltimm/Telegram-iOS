import Foundation
import UIKit
import AsyncDisplayKit

public final class ChatListArchiveCoverNode: ASDisplayNode {
    override public func didLoad() {
        super.didLoad()

        self.backgroundColor = UIColor.blue
    }

    override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let spec = ASLayoutSpec()
        spec.style.preferredSize = CGSize(
            width: constrainedSize.max.width,
            height: constrainedSize.max.height
        )
        return spec
    }
}
