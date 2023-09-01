import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData

public final class ChatListArchiveCoverNode: ASDisplayNode {
    private let hintFont = Font.regular(17.0)
    public static let archiveCoverScrollHeight: CGFloat = {
        // TODO: Use properly calculated chat list item height
        return 77.0
    }()

    // MARK: - Subnodes

    private let pullDownToRevealHintTextNode = TextNode()
    private let releaseToRevealHintTextNode = TextNode()

    private let focusCircleContainerNode = ASDisplayNode()
    private let focusCircleNode = ASDisplayNode()

    // MARK: - State

    // TODO: Use localized
    private let pullDownToRevealHint = "Swipe down for archive"
    private let releaseToRevealHint = "Release for archive"

    // TODO: Use gradient background
    private let nonFocusColor: UIColor = UIColor(white: 0.75, alpha: 1.0)
    private let focusColor: UIColor = UIColor(
        displayP3Red: 90 / 255,
        green: 150 / 255,
        blue: 241 / 255,
        alpha: 1.0
    )
    private let hintColor: UIColor = .white
    private let focusCircleContainerColor: UIColor = UIColor(white: 1.0, alpha: 0.25)
    private let focusCircleColor: UIColor = .white

    private let verticalInset: CGFloat = 8.0
    private let focusCircleSize = CGSize(width: 24.0, height: 24.0)

    // TODO: Inject avatar size
    private let avatarSize = CGSize(width: 60, height: 60)
    private let avatarLeftInset: CGFloat = 10.0

    private var hasPassedThreshold: Bool = false
    private var thresholdPassTransition: Transition?

    // MARK: - Lifecycle

    override public func didLoad() {
        super.didLoad()

        self.backgroundColor = nonFocusColor

        addSubnode(pullDownToRevealHintTextNode)
        addSubnode(releaseToRevealHintTextNode)
        addSubnode(focusCircleContainerNode)
        addSubnode(focusCircleNode)

        pullDownToRevealHintTextNode.alpha = 1.0
        releaseToRevealHintTextNode.alpha = 0.0

        focusCircleContainerNode.cornerRadius = focusCircleSize.width / 2
        focusCircleNode.cornerRadius = focusCircleSize.width / 2

        focusCircleContainerNode.backgroundColor = focusCircleContainerColor
        focusCircleNode.backgroundColor = focusCircleColor

        self.clipsToBounds = true
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
        transition: Transition
    ) {
        // MARK: - Progress

        let fractionComplete: CGFloat = size.height / Self.archiveCoverScrollHeight
        print("Progress: \(fractionComplete)")
        let hasPassedThreshold = fractionComplete > 1.0

        let constrainedLabelSize = CGSize(width: size.width, height: 100)

        // MARK: - Pull down to reveal hint

        let makePullDownToRevealLayout = TextNode.asyncLayout(self.pullDownToRevealHintTextNode)
        let (pullDownToRevealLabelLayout, pullDownToRevealLabelApply) = makePullDownToRevealLayout(
            TextNodeLayoutArguments(
                attributedString: NSAttributedString(
                    string: pullDownToRevealHint,
                    font: hintFont,
                    textColor: hintColor
                ),
                backgroundColor: nil,
                maximumNumberOfLines: 1,
                truncationType: .end,
                constrainedSize: constrainedLabelSize,
                alignment: .natural,
                cutout: nil,
                insets: UIEdgeInsets()
            )
        )
        let _ = pullDownToRevealLabelApply()
        let pullDownToRevealLabelSize = pullDownToRevealLabelLayout.size

        // MARK: - Release to reveal hint

        let makeReleaseToRevealLayout = TextNode.asyncLayout(self.releaseToRevealHintTextNode)
        let (releaseToRevealLabelLayout, releaseToRevealLabelApply) = makeReleaseToRevealLayout(
            TextNodeLayoutArguments(
                attributedString: NSAttributedString(
                    string: releaseToRevealHint,
                    font: hintFont,
                    textColor: hintColor
                ),
                backgroundColor: nil,
                maximumNumberOfLines: 1,
                truncationType: .end,
                constrainedSize: constrainedLabelSize,
                alignment: .natural,
                cutout: nil,
                insets: UIEdgeInsets()
            )
        )
        let _ = releaseToRevealLabelApply()
        let releaseToRevealLabelSize = releaseToRevealLabelLayout.size

        // MARK: - Frame updates

        let pullDownToRevealHintFrameBelowThreshold = CGRect(
            origin: CGPoint(
                x: (size.width - pullDownToRevealLabelSize.width) / 2,
                y: size.height - verticalInset - pullDownToRevealLabelSize.height
            ),
            size: pullDownToRevealLabelSize
        )
        var pullDownToRevealHintFrameAfterThreshold = pullDownToRevealHintFrameBelowThreshold
        pullDownToRevealHintFrameAfterThreshold.origin.x = size.width

        let releaseToRevealHintFrameAfterThreshold = CGRect(
            origin: CGPoint(
                x: (size.width - releaseToRevealLabelSize.width) / 2,
                y: size.height - verticalInset - releaseToRevealLabelSize.height
            ),
            size: releaseToRevealLabelSize
        )
        var releaseToRevealHintFrameBelowThreshold = releaseToRevealHintFrameAfterThreshold
        releaseToRevealHintFrameBelowThreshold.origin.x = -releaseToRevealLabelSize.width

        let focusCircleOriginX = leftInset + avatarLeftInset + (avatarSize.width - focusCircleSize.width) / 2
        let focusCircleContainerFrame = CGRect(
            origin: CGPoint(
                x: focusCircleOriginX,
                y: min(verticalInset, size.height - focusCircleSize.height - verticalInset)
            ),
            size: CGSize(
                width: focusCircleSize.width,
                height: max(size.height - 2 * verticalInset, focusCircleSize.height)
            )
        )

        let focusCircleFrame = CGRect(
            origin: CGPoint(
                x: focusCircleOriginX,
                y: size.height - focusCircleSize.height - verticalInset
            ),
            size: focusCircleSize
        )

        // MARK: - Threshold pass animation

        if hasPassedThreshold != self.hasPassedThreshold, self.thresholdPassTransition == nil {
            let thresholdPassTransition = transition
            self.thresholdPassTransition = thresholdPassTransition
            self.hasPassedThreshold = hasPassedThreshold

            if hasPassedThreshold {
                thresholdPassTransition.setBackgroundColor(layer: self.layer, color: focusColor)
                thresholdPassTransition.animateAlpha(
                    layer: pullDownToRevealHintTextNode.layer,
                    from: 1.0,
                    to: 0.0
                )
                thresholdPassTransition.animateAlpha(
                    layer: releaseToRevealHintTextNode.layer,
                    from: 0.0,
                    to: 1.0
                )

                thresholdPassTransition.containedViewLayoutTransition.animateFrame(
                    node: pullDownToRevealHintTextNode,
                    from: pullDownToRevealHintFrameBelowThreshold,
                    to: pullDownToRevealHintFrameAfterThreshold
                )
                thresholdPassTransition.containedViewLayoutTransition.animateFrame(
                    node: releaseToRevealHintTextNode,
                    from: releaseToRevealHintFrameBelowThreshold,
                    to: releaseToRevealHintFrameAfterThreshold
                )
            } else {
                thresholdPassTransition.setBackgroundColor(layer: self.layer, color: nonFocusColor)
                thresholdPassTransition.animateAlpha(
                    layer: pullDownToRevealHintTextNode.layer,
                    from: 0.0,
                    to: 1.0
                )
                thresholdPassTransition.animateAlpha(
                    layer: releaseToRevealHintTextNode.layer,
                    from: 1.0,
                    to: 0.0
                )

                thresholdPassTransition.containedViewLayoutTransition.animateFrame(
                    node: pullDownToRevealHintTextNode,
                    from: pullDownToRevealHintFrameBelowThreshold,
                    to: pullDownToRevealHintFrameAfterThreshold
                )
                thresholdPassTransition.containedViewLayoutTransition.animateFrame(
                    node: releaseToRevealHintTextNode,
                    from: releaseToRevealHintFrameBelowThreshold,
                    to: releaseToRevealHintFrameAfterThreshold
                )
            }
        } else {
            if hasPassedThreshold {
                transition.containedViewLayoutTransition.updateBackgroundColor(node: self, color: focusColor)
                transition.containedViewLayoutTransition.updateAlpha(node: pullDownToRevealHintTextNode, alpha: 0.0)
                transition.containedViewLayoutTransition.updateAlpha(node: releaseToRevealHintTextNode, alpha: 1.0)

                transition.containedViewLayoutTransition.updateFrame(
                    node: pullDownToRevealHintTextNode,
                    frame: pullDownToRevealHintFrameAfterThreshold
                )
                transition.containedViewLayoutTransition.updateFrame(
                    node: releaseToRevealHintTextNode,
                    frame: releaseToRevealHintFrameAfterThreshold
                )
            } else {
                transition.containedViewLayoutTransition.updateBackgroundColor(node: self, color: nonFocusColor)
                transition.containedViewLayoutTransition.updateAlpha(node: pullDownToRevealHintTextNode, alpha: 1.0)
                transition.containedViewLayoutTransition.updateAlpha(node: releaseToRevealHintTextNode, alpha: 0.0)

                transition.containedViewLayoutTransition.updateFrame(
                    node: pullDownToRevealHintTextNode,
                    frame: pullDownToRevealHintFrameBelowThreshold
                )
                transition.containedViewLayoutTransition.updateFrame(
                    node: releaseToRevealHintTextNode,
                    frame: releaseToRevealHintFrameBelowThreshold
                )
            }
        }

        transition.containedViewLayoutTransition.updateFrame(node: focusCircleContainerNode, frame: focusCircleContainerFrame)
        transition.containedViewLayoutTransition.updateFrame(node: focusCircleNode, frame: focusCircleFrame)
    }
}
