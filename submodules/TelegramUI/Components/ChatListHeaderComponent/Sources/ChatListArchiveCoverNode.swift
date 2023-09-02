import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData

public final class ChatListArchiveCoverNode: ASDisplayNode {
    private let hintFont = Font.bold(17.0)
    public static let archiveCoverScrollHeight: CGFloat = {
        // TODO: Use properly calculated chat list item height
        return 77.0
    }()

    // MARK: - Subnodes

    private let backgroundNode = LinearGradientNode()
    private let focusBackgroundNode = LinearGradientNode()

    private let pullDownToRevealWrapperNode = ASDisplayNode()
    private let releaseToRevealWrapperNode = ASDisplayNode()
    private let pullDownToRevealHintTextNode = TextNode()
    private let releaseToRevealHintTextNode = TextNode()

    private let focusCircleContainerNode = ASDisplayNode()
    private let focusCircleNode = ASDisplayNode()

    // MARK: - State

    // TODO: Use localized
    private let pullDownToRevealHint = "Swipe down for archive"
    private let releaseToRevealHint = "Release for archive"

    // TODO: Use theme background
    private let nonFocusColor1: UIColor = .dynamic(
        light: UIColor(
            displayP3Red: 178 / 255,
            green: 183 / 255,
            blue: 189 / 255,
            alpha: 1.0
        ),
        dark: UIColor(
            displayP3Red: 58 / 255,
            green: 63 / 255,
            blue: 69 / 255,
            alpha: 1.0
        )
    )
    private let nonFocusColor2: UIColor = .dynamic(
        light: UIColor(
            displayP3Red: 218 / 255,
            green: 218 / 255,
            blue: 223 / 255,
            alpha: 1.0
        ),
        dark: UIColor(
            displayP3Red: 88 / 255,
            green: 88 / 255,
            blue: 93 / 255,
            alpha: 1.0
        )
    )
    private let focusColor1: UIColor = UIColor(
        displayP3Red: 60 / 255,
        green: 132 / 255,
        blue: 235 / 255,
        alpha: 1.0
    )
    private let focusColor2: UIColor = UIColor(
        displayP3Red: 138 / 255,
        green: 196 / 255,
        blue: 250 / 255,
        alpha: 1.0
    )
    private let hintColor: UIColor = .white
    private let focusCircleContainerColor: UIColor = UIColor(white: 1.0, alpha: 0.25)
    private let focusCircleColor: UIColor = .white

    private let verticalInset: CGFloat = 8.0
    private let focusCircleSize = CGSize(width: 20.0, height: 20.0)

    // TODO: Inject avatar size
    private let avatarSize = CGSize(width: 60, height: 60)
    private let avatarLeftInset: CGFloat = 10.0

    private var hasPassedThreshold: Bool = false

    // MARK: - Lifecycle

    override public func didLoad() {
        super.didLoad()

        self.backgroundColor = .clear

        addSubnode(backgroundNode)
        addSubnode(focusBackgroundNode)
        addSubnode(pullDownToRevealWrapperNode)
        pullDownToRevealWrapperNode.addSubnode(pullDownToRevealHintTextNode)
        addSubnode(releaseToRevealWrapperNode)
        releaseToRevealWrapperNode.addSubnode(releaseToRevealHintTextNode)
        addSubnode(focusCircleContainerNode)
        addSubnode(focusCircleNode)

        backgroundNode.colors = [nonFocusColor1, nonFocusColor2]
        backgroundNode.locations = [0, 1]

        focusBackgroundNode.colors = [focusColor1, focusColor2]
        focusBackgroundNode.locations = [0, 1]
        focusBackgroundNode.alpha = 0.0
        focusBackgroundNode.cornerRadius = focusCircleSize.width / 2
        focusBackgroundNode.layer.masksToBounds = true

        pullDownToRevealWrapperNode.alpha = 1.0
        releaseToRevealWrapperNode.alpha = 0.0

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
        transition: ContainedViewLayoutTransition
    ) {
        // MARK: - Progress

        let fractionComplete: CGFloat = size.height / Self.archiveCoverScrollHeight
        let hasPassedThreshold: Bool
        if fractionComplete > 1.0 {
            hasPassedThreshold = true
        } else if fractionComplete < 0.95 {
            hasPassedThreshold = false
        } else {
            hasPassedThreshold = self.hasPassedThreshold
        }

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

        let backgroundFrame = CGRect(origin: .zero, size: size)

        let pullDownToRevealHintFrame = CGRect(
            origin: CGPoint(
                x: (size.width - pullDownToRevealLabelSize.width) / 2,
                y: size.height - verticalInset - pullDownToRevealLabelSize.height
            ),
            size: pullDownToRevealLabelSize
        )

        let releaseToRevealHintFrame = CGRect(
            origin: CGPoint(
                x: (size.width - releaseToRevealLabelSize.width) / 2,
                y: size.height - verticalInset - releaseToRevealLabelSize.height
            ),
            size: releaseToRevealLabelSize
        )

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

        // MARK: - Update Frames

        backgroundNode.frame = backgroundFrame
        focusBackgroundNode.frame = focusCircleFrame

        pullDownToRevealWrapperNode.frame = pullDownToRevealHintFrame
        pullDownToRevealHintTextNode.frame = CGRect(origin: .zero, size: pullDownToRevealHintFrame.size)
        releaseToRevealWrapperNode.frame = releaseToRevealHintFrame
        releaseToRevealHintTextNode.frame = CGRect(origin: .zero, size: releaseToRevealHintFrame.size)

        focusCircleContainerNode.frame = focusCircleContainerFrame
        focusCircleNode.frame = focusCircleFrame

        // MARK: - Threshold pass animation

        if hasPassedThreshold != self.hasPassedThreshold {
            self.hasPassedThreshold = hasPassedThreshold

            let focusBackgroundSizeFactor = 2 * size.width / focusCircleSize.width
            let pullDownToRevealTranslation = size.width - pullDownToRevealHintFrame.minX
            let releaseToRevealTranslation = -releaseToRevealHintFrame.maxX
            if hasPassedThreshold {
                focusBackgroundNode.alpha = 1.0
                pullDownToRevealWrapperNode.view.transform = .identity
                releaseToRevealWrapperNode.view.transform = CGAffineTransform(
                    translationX: releaseToRevealTranslation,
                    y: 0.0
                )
            } else {
                pullDownToRevealWrapperNode.view.transform = CGAffineTransform(
                    translationX: pullDownToRevealTranslation,
                    y: 0.0
                )
                releaseToRevealWrapperNode.view.transform = .identity
            }

            UIView.animate(
                withDuration: 0.45,
                delay: 0.0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.0,
                options: [.beginFromCurrentState, .allowAnimatedContent, .allowUserInteraction]
            ) {
                self.focusBackgroundNode.view.transform = hasPassedThreshold ? CGAffineTransform(
                    scaleX: focusBackgroundSizeFactor,
                    y: focusBackgroundSizeFactor
                ) : .identity

                self.pullDownToRevealWrapperNode.view.alpha = hasPassedThreshold ? 0.0 : 1.0
                self.releaseToRevealWrapperNode.view.alpha = hasPassedThreshold ? 1.0 : 0.0

                self.pullDownToRevealWrapperNode.view.transform = hasPassedThreshold ? CGAffineTransform(
                    translationX: pullDownToRevealTranslation,
                    y: 0.0
                ) : .identity
                self.releaseToRevealWrapperNode.view.transform = hasPassedThreshold ? .identity : CGAffineTransform(
                    translationX: releaseToRevealTranslation,
                    y: 0.0
                )
            }
        }
    }
}

private final class LinearGradientNode: ASDisplayNode {
    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.anchorPoint = CGPoint()
        layer.startPoint = .zero
        layer.endPoint = CGPoint(x: 1.0, y: 0.0)
        return layer
    }()

    override var frame: CGRect {
        didSet {
            updateGradientFrame()
        }
    }
    override var bounds: CGRect {
        didSet {
            updateGradientFrame()
        }
    }
    var endPoint: CGPoint {
        get { gradientLayer.endPoint }
        set { gradientLayer.endPoint = newValue }
    }
    var startPoint: CGPoint {
        get { gradientLayer.endPoint }
        set { gradientLayer.endPoint = newValue }
    }
    var locations: [NSNumber] {
        get { gradientLayer.locations ?? [] }
        set { gradientLayer.locations = newValue }
    }
    var colors: [UIColor] = [] {
        didSet {
            updateColors()
        }
    }

    override func didLoad() {
        super.didLoad()

        self.backgroundColor = .clear
        self.layer.addSublayer(gradientLayer)
        updateGradientFrame()
        updateColors()
    }

    override func asyncTraitCollectionDidChange() {
        super.asyncTraitCollectionDidChange()

        updateColors()
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let spec = ASLayoutSpec()
        let size = CGSize(
            width: constrainedSize.max.width,
            height: constrainedSize.max.height
        )
        spec.style.preferredSize = size
        return spec
    }

    private func updateColors() {
        gradientLayer.colors = colors.map { color in
            if #available(iOS 13.0, *) {
                return color.resolvedColor(with: self.view.traitCollection ).cgColor
            } else {
                return color.cgColor
            }
        }
    }

    private func updateGradientFrame() {
        CATransaction.setDisableActions(true)
        gradientLayer.frame = CGRect(origin: .zero, size: bounds.size)
        CATransaction.setDisableActions(false)
    }
}

private extension UIColor {
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor(dynamicProvider: { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return dark
                case .light, .unspecified:
                    return light
                @unknown default:
                    return light
                }
            })
        } else {
            return light
        }
    }   
}
