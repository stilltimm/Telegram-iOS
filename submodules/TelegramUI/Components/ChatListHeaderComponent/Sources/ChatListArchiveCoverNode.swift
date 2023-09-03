import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import AnimationUI

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
    private let releaseToRevealWrapperMaskNode = ASDisplayNode()
    private let releaseToRevealWrapperNode = ASDisplayNode()
    private let pullDownToRevealHintTextNode = TextNode()
    private let releaseToRevealHintTextNode = TextNode()

    private let focusCircleContainerNode = ASDisplayNode()
    private let focusCircleNode = ASDisplayNode()
    private let archiveCoverAnimationNode = AnimationNode(animation: "anim_archiveCover")
    private let archiveCoverFocusAnimationNode = AnimationNode(animation: "anim_archiveCoverFocus")

    // MARK: - State

    // TODO: Use localized
    private let pullDownToRevealHint = "Swipe down for archive"
    private let releaseToRevealHint = "Release for archive"

    // TODO: Use theme colors
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

    public private(set) var isTransitioningToArchiveReveal: Bool = false
    private var circleContainerFrameAtTheStartOfRevealTransition: CGRect?

    // MARK: - Lifecycle

    override public func didLoad() {
        super.didLoad()

        self.backgroundColor = .clear

        addSubnode(backgroundNode)
        addSubnode(focusBackgroundNode)
        addSubnode(pullDownToRevealWrapperNode)
        pullDownToRevealWrapperNode.addSubnode(pullDownToRevealHintTextNode)
        addSubnode(releaseToRevealWrapperMaskNode)
        releaseToRevealWrapperMaskNode.addSubnode(releaseToRevealWrapperNode)
        releaseToRevealWrapperNode.addSubnode(releaseToRevealHintTextNode)
        addSubnode(focusCircleContainerNode)
        addSubnode(focusCircleNode)
        focusCircleNode.addSubnode(archiveCoverAnimationNode)
        focusCircleNode.addSubnode(archiveCoverFocusAnimationNode)

        backgroundNode.colors = [nonFocusColor1, nonFocusColor2]
        backgroundNode.locations = [0, 1]

        focusBackgroundNode.colors = [focusColor1, focusColor2]
        focusBackgroundNode.locations = [0, 1]
        focusBackgroundNode.alpha = 0.0
        focusBackgroundNode.cornerRadius = focusCircleSize.width / 2
        focusBackgroundNode.layer.masksToBounds = true

        pullDownToRevealWrapperNode.alpha = 1.0
        releaseToRevealWrapperNode.alpha = 0.0
        releaseToRevealWrapperMaskNode.clipsToBounds = true

        focusCircleContainerNode.cornerRadius = focusCircleSize.width / 2
        focusCircleNode.view.transform = CGAffineTransform(rotationAngle: CGFloat.pi)

        focusCircleContainerNode.backgroundColor = focusCircleContainerColor
        focusCircleNode.backgroundColor = .clear

        archiveCoverFocusAnimationNode.view.alpha = 0.0

        self.clipsToBounds = true
    }

    override public func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let spec = ASLayoutSpec()
        var height: CGFloat = constrainedSize.max.height
        if isTransitioningToArchiveReveal {
            height = max(ChatListArchiveCoverNode.archiveCoverScrollHeight, constrainedSize.max.height)
        }
        spec.style.preferredSize = CGSize(
            width: constrainedSize.max.width,
            height: height
        )
        return spec
    }

    func updateLayout(
        size: CGSize,
        leftInset: CGFloat,
        rightInset: CGFloat,
        transition: ContainedViewLayoutTransition
    ) {
        var updatedSize: CGSize = size
        if isTransitioningToArchiveReveal {
            updatedSize.height = max(size.height, Self.archiveCoverScrollHeight)
        }

        // MARK: - Progress

        let fractionComplete: CGFloat = updatedSize.height / Self.archiveCoverScrollHeight
        let hasPassedThreshold: Bool
        if fractionComplete > 1.0 {
            hasPassedThreshold = true
        } else if fractionComplete < 0.95 {
            hasPassedThreshold = false
        } else {
            hasPassedThreshold = self.hasPassedThreshold
        }

        let constrainedLabelSize = CGSize(width: updatedSize.width, height: 100)

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

        let backgroundFrame = CGRect(origin: .zero, size: updatedSize)

        let focusCircleOriginX = leftInset + avatarLeftInset + (avatarSize.width - focusCircleSize.width) / 2
        let focusCircleContainerFrame = CGRect(
            origin: CGPoint(
                x: focusCircleOriginX,
                y: min(verticalInset, updatedSize.height - focusCircleSize.height - verticalInset)
            ),
            size: CGSize(
                width: focusCircleSize.width,
                height: max(updatedSize.height - 2 * verticalInset, focusCircleSize.height)
            )
        )

        let focusCircleFrame = CGRect(
            origin: CGPoint(
                x: focusCircleOriginX,
                y: updatedSize.height - focusCircleSize.height - verticalInset
            ),
            size: focusCircleSize
        )

        let animationFrame = CGRect(
            origin: CGPoint(
                x: (focusCircleSize.width - avatarSize.width) / 2,
                y: (focusCircleSize.height - avatarSize.height) / 2 - 4 // magic number to adjust circle position
            ),
            size: avatarSize
        )

        let pullDownToRevealWrapperFrame = CGRect(
            origin: CGPoint(
                x: (updatedSize.width - pullDownToRevealLabelSize.width) / 2,
                y: updatedSize.height - verticalInset - pullDownToRevealLabelSize.height
            ),
            size: pullDownToRevealLabelSize
        )
        var pullDownToRevealHintFrame = pullDownToRevealWrapperFrame
        pullDownToRevealHintFrame.origin = .zero

        let releaseToRevealMaskFrame = CGRect(
            origin: CGPoint(
                x: focusCircleFrame.midX,
                y: updatedSize.height - verticalInset - releaseToRevealLabelSize.height
            ),
            size: CGSize(
                width: updatedSize.width - focusCircleFrame.midX,
                height: releaseToRevealLabelSize.height
            )
        )
        var releaseToRevealWrapperFrame = releaseToRevealMaskFrame
        releaseToRevealWrapperFrame.origin = .zero
        let releaseToRevealHintFrame = CGRect(
            origin: CGPoint(
                x: (updatedSize.width - releaseToRevealLabelSize.width) / 2 - focusCircleFrame.midX,
                y: 0
            ),
            size: releaseToRevealLabelSize
        )

        // MARK: - Update Frames

        backgroundNode.frame = backgroundFrame
        backgroundNode.view.alpha = 0.5
        focusBackgroundNode.frame = focusCircleFrame

        pullDownToRevealWrapperNode.frame = pullDownToRevealWrapperFrame
        pullDownToRevealHintTextNode.frame = pullDownToRevealHintFrame
        releaseToRevealWrapperMaskNode.frame = releaseToRevealMaskFrame
        releaseToRevealWrapperNode.frame = releaseToRevealWrapperFrame
        releaseToRevealHintTextNode.frame = releaseToRevealHintFrame

        focusCircleContainerNode.frame = focusCircleContainerFrame
        focusCircleNode.frame = focusCircleFrame
        archiveCoverAnimationNode.frame = animationFrame
        archiveCoverFocusAnimationNode.frame = animationFrame

        // MARK: - Threshold pass animation

        if hasPassedThreshold != self.hasPassedThreshold {
            self.hasPassedThreshold = hasPassedThreshold

            let focusBackgroundSizeFactor = 2 * updatedSize.width / focusCircleSize.width
            let pullDownToRevealTranslation = updatedSize.width - pullDownToRevealHintFrame.minX
            let releaseToRevealTranslation = -releaseToRevealHintFrame.maxX
            CATransaction.setDisableActions(true)
            if hasPassedThreshold {
                focusBackgroundNode.alpha = 0.5
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
                focusBackgroundNode.cornerRadius = focusCircleSize.width / 2
            }
            CATransaction.setDisableActions(false)

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                UIView.animate(
                    withDuration: 0.4,
                    delay: 0.0,
                    usingSpringWithDamping: 0.78,
                    initialSpringVelocity: 0.0,
                    options: [.beginFromCurrentState, .allowAnimatedContent, .allowUserInteraction]
                ) {
                    self.focusBackgroundNode.view.transform = hasPassedThreshold ? CGAffineTransform(
                        scaleX: focusBackgroundSizeFactor,
                        y: focusBackgroundSizeFactor
                    ) : .identity
                    self.focusCircleNode.view.transform = hasPassedThreshold ? CGAffineTransform(
                        rotationAngle: -2 * CGFloat.pi
                    ) : CGAffineTransform(
                        rotationAngle: CGFloat.pi
                    )
                    self.archiveCoverFocusAnimationNode.view.alpha = hasPassedThreshold ? 1.0 : 0.0

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
                } completion : { [weak self] completed in
                    guard let strongSelf = self, completed else { return }
                    if hasPassedThreshold {
                        strongSelf.focusBackgroundNode.cornerRadius = 0.0
                    } else {
                        strongSelf.focusBackgroundNode.cornerRadius = strongSelf.focusCircleSize.width / 2
                    }
                }
            }
        }
    }

    public func transitionToArchiveReveal() {
        guard self.hasPassedThreshold else {
            return
        }

        self.isTransitioningToArchiveReveal = true
    }

    public func applyTransitionToArchiveRevealProgress(progress: CGFloat?) {
        let initialFocusBackgroundSizeFactor = 2 * bounds.width / focusCircleSize.width
        guard let progress else {
            backgroundNode.alpha = 0.0

            pullDownToRevealWrapperNode.alpha = 0.0
            pullDownToRevealWrapperNode.view.layer.removeAllAnimations()
            pullDownToRevealWrapperNode.view.transform = .identity

            releaseToRevealWrapperNode.alpha = 1.0
            releaseToRevealWrapperNode.view.layer.removeAllAnimations()
            releaseToRevealWrapperNode.view.transform = .identity

            focusBackgroundNode.cornerRadius = focusCircleSize.width / 2
            focusBackgroundNode.view.layer.removeAllAnimations()
            focusBackgroundNode.view.transform = CGAffineTransform(
                scaleX: initialFocusBackgroundSizeFactor,
                y: initialFocusBackgroundSizeFactor
            )

            circleContainerFrameAtTheStartOfRevealTransition = focusCircleContainerNode.frame
            return
        }

        CATransaction.setDisableActions(true)
        let focusBackgroundSizeTargetFactor = avatarSize.width / focusCircleSize.width
        let focusBackgroundSizeFactor = focusBackgroundSizeTargetFactor + (1.0 - progress) * (initialFocusBackgroundSizeFactor - focusBackgroundSizeTargetFactor)
        print("Progress = \(ceil(progress * 100.0)),\tFactor = \(ceil(1000.0 * focusBackgroundSizeFactor) / 1000.0)")
        focusBackgroundNode.view.transform = CGAffineTransform(
            scaleX: focusBackgroundSizeFactor,
            y: focusBackgroundSizeFactor
        )

        releaseToRevealWrapperNode.alpha = 1.0 - progress

        if let initialFrame = circleContainerFrameAtTheStartOfRevealTransition {
            let focusContainerProgress = min(1.0, progress * 2.0)
            var updatedFocusContainerFrame = initialFrame
            var updatedHeight = focusCircleSize.height + (1.0 - focusContainerProgress) * (updatedFocusContainerFrame.height - focusCircleSize.height)
            updatedHeight = max(updatedHeight, 0.0)
            updatedFocusContainerFrame.origin.y = initialFrame.origin.y + (initialFrame.height - updatedHeight)
            updatedFocusContainerFrame.size.height = updatedHeight
            focusCircleContainerNode.frame = updatedFocusContainerFrame

            if focusContainerProgress >= 1.0 {
                focusCircleContainerNode.alpha = 0.0 - progress
            }
        }

        if progress >= 1.0 {
            isTransitioningToArchiveReveal = false
            circleContainerFrameAtTheStartOfRevealTransition = nil
        }
        CATransaction.setDisableActions(false)
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
