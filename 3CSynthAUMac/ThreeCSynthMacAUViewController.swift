// ThreeCSynthMacAUViewController.swift
// 3CSynthAUMac
//
// View controller that hosts the SwiftUI synthesizer UI inside the macOS
// AUv3 extension. Logic Pro presents this view in the plug-in window.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import AudioToolbox
import CoreAudioKit
import SwiftUI

// MARK: - ThreeCSynthMacAUViewController

/// The `AUViewController` subclass for the 3CSynth macOS AUv3 plug-in.
///
/// Logic Pro instantiates this class when the user opens the plug-in window.
/// `createAudioUnit(with:)` is called first; `viewDidLoad()` may be called
/// before or after, so both paths wire the UI defensively.
public final class ThreeCSynthMacAUViewController: AUViewController, AUAudioUnitFactory {

    // MARK: Properties

    public private(set) var audioUnit: ThreeCSynthMacAudioUnit?
    private var hostingController: NSHostingController<AnyView>?

    // MARK: AUAudioUnitFactory

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let au = try ThreeCSynthMacAudioUnit(componentDescription: componentDescription)
        audioUnit = au

        if isViewLoaded {
            embedSynthUI(parameters: au.synthParameters)
        }
        return au
    }

    // MARK: View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        if let au = audioUnit {
            embedSynthUI(parameters: au.synthParameters)
        }
    }

    // MARK: Private

    private func embedSynthUI(parameters: SynthParameters) {
        // Remove any previously embedded controller.
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        let synthView = SynthView(parameters: parameters, isPlugin: true)
        let hc = NSHostingController(rootView: AnyView(synthView))

        addChild(hc)
        hc.view.frame = view.bounds
        hc.view.autoresizingMask = [.width, .height]
        view.addSubview(hc.view)

        hostingController = hc

        // Logic Pro respects this size when it opens the plug-in window.
        preferredContentSize = NSSize(width: 900, height: 540)
    }
}
