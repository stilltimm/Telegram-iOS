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
    private var frameAtTheStartOfRevealTransition: CGRect?
    private var focusBackgroundFrameAtTheStartOfRevealTransition: CGRect?
    private var focusCircleFrameAtTheStartOfRevealTransition: CGRect?

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

        self.clipsToBounds = true

        resetToInitialState()
    }

    public func resetToInitialState() {
        hasPassedThreshold = false
        isTransitioningToArchiveReveal = false
        frameAtTheStartOfRevealTransition = nil
        circleContainerFrameAtTheStartOfRevealTransition = nil
        focusBackgroundFrameAtTheStartOfRevealTransition = nil
        focusCircleFrameAtTheStartOfRevealTransition = nil

        backgroundNode.colors = [nonFocusColor1, nonFocusColor2]
        backgroundNode.locations = [0, 1]
        backgroundNode.alpha = 1.0

        focusBackgroundNode.colors = [focusColor1, focusColor2]
        focusBackgroundNode.locations = [0, 1]
        focusBackgroundNode.alpha = 0.0
        focusBackgroundNode.cornerRadius = focusCircleSize.width / 2
        focusBackgroundNode.layer.masksToBounds = true

        pullDownToRevealWrapperNode.alpha = 1.0
        releaseToRevealWrapperNode.alpha = 0.0
        releaseToRevealWrapperMaskNode.clipsToBounds = true

        focusCircleContainerNode.alpha = 1.0
        focusCircleContainerNode.cornerRadius = focusCircleSize.width / 2
        focusCircleContainerNode.backgroundColor = focusCircleContainerColor

        focusCircleNode.view.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        focusCircleNode.backgroundColor = .clear

        archiveCoverAnimationNode.view.alpha = 1.0
        archiveCoverFocusAnimationNode.view.alpha = 0.0
        archiveCoverFocusAnimationNode.setProgress(0.0)
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

        self.frameAtTheStartOfRevealTransition = self.view.frame
        self.circleContainerFrameAtTheStartOfRevealTransition = focusCircleContainerFrame
        self.focusBackgroundFrameAtTheStartOfRevealTransition = focusCircleFrame
        self.focusCircleFrameAtTheStartOfRevealTransition = focusCircleFrame

        // MARK: - Threshold pass animation

        if hasPassedThreshold != self.hasPassedThreshold {
            self.hasPassedThreshold = hasPassedThreshold

            let focusBackgroundSizeFactor = 2 * updatedSize.width / focusCircleSize.width
            let pullDownToRevealTranslation = updatedSize.width - pullDownToRevealHintFrame.minX
            let releaseToRevealTranslation = -releaseToRevealHintFrame.maxX
            CATransaction.setDisableActions(true)
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

    // MARK: - Archive reveal transition

    public func transitionToArchiveReveal() {
        guard self.hasPassedThreshold else {
            return
        }

        self.isTransitioningToArchiveReveal = true
    }

    public func applyTransitionToArchiveRevealProgress(progress: CGFloat?) {
        let initialFocusBackgroundSizeFactor = 2 * bounds.width / focusCircleSize.width
        guard
            let progress,
            let frameAtTheStartOfRevealTransition,
            let circleContainerFrameAtTheStartOfRevealTransition,
            let focusBackgroundFrameAtTheStartOfRevealTransition,
            let focusCircleFrameAtTheStartOfRevealTransition
        else {
            // MARK: - Start of transition setup
            CATransaction.setDisableActions(true)
            backgroundNode.view.layer.removeAllAnimations()
            backgroundNode.alpha = 0.0

            pullDownToRevealWrapperNode.view.layer.removeAllAnimations()
            pullDownToRevealWrapperNode.alpha = 0.0
            pullDownToRevealWrapperNode.view.transform = .identity

            releaseToRevealWrapperNode.view.layer.removeAllAnimations()
            releaseToRevealWrapperNode.alpha = 1.0
            releaseToRevealWrapperNode.view.transform = .identity

            focusBackgroundNode.view.layer.removeAllAnimations()
            focusBackgroundNode.cornerRadius = focusCircleSize.width / 2
            focusBackgroundNode.view.transform = CGAffineTransform(
                scaleX: initialFocusBackgroundSizeFactor,
                y: initialFocusBackgroundSizeFactor
            )
            CATransaction.setDisableActions(false)

            archiveCoverAnimationNode.alpha = 0.0
            archiveCoverFocusAnimationNode.alpha = 1.0

            return
        }

        // NOTE: Map linear progress to cubic progress to mimic ".easeOut" curve
        let cubicProgress = easeOutCubic(x: progress)

        CATransaction.setDisableActions(true)

        // MARK: - Interpolations / self.frame & background.frame

        let updatedFrame = CGRect.interpolatedRect(
            from: frameAtTheStartOfRevealTransition,
            to: CGRect(
                origin: frameAtTheStartOfRevealTransition.origin,
                size: CGSize(
                    width: frameAtTheStartOfRevealTransition.size.width,
                    height: Self.archiveCoverScrollHeight
                )
            ),
            with: progress
        )
        self.view.frame = updatedFrame

        self.backgroundNode.view.frame = CGRect(origin: .zero, size: updatedFrame.size)

        // MARK: - Interpolations / circleContainer

        let updatedFocusContainerFrame = CGRect.interpolatedRect(
            from: circleContainerFrameAtTheStartOfRevealTransition,
            to: CGRect(
                origin: CGPoint(
                    x: circleContainerFrameAtTheStartOfRevealTransition.origin.x,
                    y: (Self.archiveCoverScrollHeight - focusCircleSize.height) / 2.0
                ),
                size: focusCircleSize
            ),
            with: progress
        )
        focusCircleContainerNode.frame = updatedFocusContainerFrame

        // MARK: - Interpolations / Focus background

        let focusBackgroundTargetFrame = CGRect(
            origin: CGPoint(
                x: focusBackgroundFrameAtTheStartOfRevealTransition.origin.x,
                y: (Self.archiveCoverScrollHeight - focusCircleSize.height) / 2.0
            ),
            size: focusCircleSize
        )
        let focusBackgroundFrame = CGRect.interpolatedRect(
            from: focusBackgroundFrameAtTheStartOfRevealTransition,
            to: focusBackgroundTargetFrame,
            with: progress
        )
        focusBackgroundNode.frame = focusBackgroundFrame

        let focusBackgroundSizeFactor = CGFloat.interpolatedValue(
            from: initialFocusBackgroundSizeFactor,
            to: avatarSize.width / focusCircleSize.width,
            with: cubicProgress
        )
        focusBackgroundNode.view.transform = CGAffineTransform(
            scaleX: focusBackgroundSizeFactor,
            y: focusBackgroundSizeFactor
        )

        // MARK: - Interpolations / focusCircleNode

        let focusCircleTargetFrame = CGRect(
            origin: CGPoint(
                x: focusCircleFrameAtTheStartOfRevealTransition.origin.x,
                y: (Self.archiveCoverScrollHeight - focusCircleSize.height) / 2.0 + 4 // magic number to correct animation
            ),
            size: focusCircleSize
        )
        let focusCircleFrame = CGRect.interpolatedRect(
            from: focusCircleFrameAtTheStartOfRevealTransition,
            to: focusCircleTargetFrame,
            with: progress
        )
        focusCircleNode.frame = focusCircleFrame

        // MARK: - Interpolations / archiveCoverFocusAnimationNode

        archiveCoverFocusAnimationNode.setProgress(progress)

        // MARK: - Interpolations / releaseToRevealWrapperNode

        let releaseToRevealHeightBottomInset = releaseToRevealWrapperMaskNode.frame.size.height + verticalInset
        let releaseToRevealWrapperNodeFrame = CGRect(
            origin: CGPoint(
                x: releaseToRevealWrapperMaskNode.frame.origin.x,
                y: CGFloat.interpolatedValue(
                    from: frameAtTheStartOfRevealTransition.size.height - releaseToRevealHeightBottomInset,
                    to: Self.archiveCoverScrollHeight - releaseToRevealHeightBottomInset,
                    with: progress
                )
            ),
            size: releaseToRevealWrapperMaskNode.frame.size
        )
        releaseToRevealWrapperMaskNode.frame = releaseToRevealWrapperNodeFrame

        releaseToRevealWrapperNode.alpha = 1.0 - cubicProgress

        // MARK: - Finish transition & reset

        CATransaction.setDisableActions(false)
    }

    // NOTE: Formula taken from
    // https://easings.net/#easeOutCubic
    private func easeOutCubic(x: CGFloat) -> CGFloat {
        return 1 - pow(1 - x, 3)
    }
}

private final class LinearGradientNode: ASDisplayNode {
    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
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

private extension CGRect {
    static func interpolatedRect(from: CGRect, to: CGRect, with progress: CGFloat) -> CGRect {
        return CGRect(
            x: CGFloat.interpolatedValue(from: from.origin.x, to: to.origin.x, with: progress),
            y: CGFloat.interpolatedValue(from: from.origin.y, to: to.origin.y, with: progress),
            width: CGFloat.interpolatedValue(from: from.size.width, to: to.size.width, with: progress),
            height: CGFloat.interpolatedValue(from: from.size.height, to: to.size.height, with: progress)
        )
    }
}

private extension CGFloat {
    static func interpolatedValue(from: CGFloat, to: CGFloat, with progress: CGFloat) -> CGFloat {
        return from + progress * (to - from)
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
