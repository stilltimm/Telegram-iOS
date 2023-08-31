import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData

//public func archiveCoverNodeHeight(
//    chatListItem: ChatListItem,
//    params: ListViewItemLayoutParams
//) -> CGFloat {
//    let chatListItemLayoutBlock = ChatListItemNode().asyncLayout()
//    let layout = chatListItemLayoutBlock(
//        chatListItem,
//        params,
//        false,
//        false,
//        false,
//        false
//    )
//}

public final class ChatListArchiveCoverNode: ASDisplayNode {
    private let hintFont = Font.regular(17.0)
    public static let archiveCoverScrollHeight: CGFloat = {
        // TODO: Use properly calculated chat list item height
        return 77.0
    }()

    var initialHintTextNode: ASDisplayNode?
    var thresholdHintTextNode: ASDisplayNode?
    var avatarCoverNode: ASDisplayNode?
    var animatableArrowToArchiveIconNode: ASDisplayNode?

    override public func didLoad() {
        super.didLoad()

        self.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.5)

        initialHintTextNode = TextNode()
    }

    override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let spec = ASLayoutSpec()
        spec.style.preferredSize = CGSize(
            width: constrainedSize.max.width,
            height: constrainedSize.max.height
        )
        return spec
    }

    func updateLayout(
        size: CGSize,
        leftInset: CGFloat,
        rightInset: CGFloat,
        transition: ContainedViewLayoutTransition
    ) {
    }
}
