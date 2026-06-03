// ThreeCSynthAudioUnitViewController.swift
// 3CSynthAU
//
// View controller that hosts the SwiftUI synthesizer UI inside the AUv3
// extension. Logic Pro presents this view in the plug-in window.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import AudioToolbox
import CoreAudioKit
import SwiftUI

// MARK: - ThreeCSynthAudioUnitViewController

/// The `AUViewController` subclass for the 3CSynth AUv3 plug-in.
///
/// When Logic Pro opens a plug-in window it instantiates this class and calls
/// ``viewDidLoad()``. We embed a `UIHostingController` containing the SwiftUI
/// `SynthView` into the view hierarchy, wiring it to the shared
/// `SynthParameters` from the audio unit.
public final class ThreeCSynthAudioUnitViewController: AUViewController, AUAudioUnitFactory {

    // MARK: Properties

    /// The associated audio unit; set by `createAudioUnit(with:)`.
    public private(set) var audioUnit: ThreeCSynthAudioUnit?

    private var hostingController: UIHostingController<AnyView>?

    // MARK: AUAudioUnitFactory

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let au = try ThreeCSynthAudioUnit(componentDescription: componentDescription)
        audioUnit = au

        // If the view is already loaded, wire the UI to the new audio unit.
        if isViewLoaded {
            embedSynthUI(parameters: au.synthParameters)
        }
        return au
    }

    // MARK: View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        if let au = audioUnit {
            embedSynthUI(parameters: au.synthParameters)
        }
    }

    // MARK: Private

    private func embedSynthUI(parameters: SynthParameters) {
        // Remove any previously embedded controller.
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        let synthView = SynthView(parameters: parameters, isPlugin: true)
        let hc = UIHostingController(rootView: AnyView(synthView))
        addChild(hc)
        hc.view.frame = view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hc.view)
        hc.didMove(toParent: self)
        hostingController = hc

        // AU preferred content size (Logic Pro will respect this).
        preferredContentSize = CGSize(width: 900, height: 540)
    }
}
