//
//  QRScannerViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 8/20/25.
//
import UIKit
import AVFoundation

// MARK: - QR Scanner
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let metadataOutput = AVCaptureMetadataOutput()

    private let guideView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        return view
    }()

    private var overlayLayer: CAShapeLayer?
    private lazy var guideSize: CGFloat = view.frame.width * 0.8
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])

        view.addSubview(guideView)
        NSLayoutConstraint.activate([
            guideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guideView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guideView.widthAnchor.constraint(equalToConstant: guideSize),
            guideView.heightAnchor.constraint(equalTo: guideView.widthAnchor)
        ])

        updateOverlayMaskAndRectOfInterest()
        view.bringSubviewToFront(closeButton)
        view.bringSubviewToFront(guideView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateOverlayMaskAndRectOfInterest()
    }

    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            dismiss(animated: true)
            return
        }

        captureSession.addInput(videoInput)

        guard captureSession.canAddOutput(metadataOutput) else {
            dismiss(animated: true)
            return
        }
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer

        DispatchQueue.main.async {
            self.captureSession.startRunning()
        }
    }

    private func updateOverlayMaskAndRectOfInterest() {
        let roundedRect = guideView.frame

        let path = UIBezierPath(rect: view.bounds)
        let cutoutPath = UIBezierPath(roundedRect: roundedRect, cornerRadius: guideView.layer.cornerRadius)
        path.append(cutoutPath)
        path.usesEvenOddFillRule = true

        if overlayLayer == nil {
            let layer = CAShapeLayer()
            layer.fillRule = .evenOdd
            layer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
            view.layer.addSublayer(layer)
            overlayLayer = layer
        }
        overlayLayer?.frame = view.bounds
        overlayLayer?.path = path.cgPath

        if let previewLayer = previewLayer {
            let interest = previewLayer.metadataOutputRectConverted(fromLayerRect: roundedRect)
            metadataOutput.rectOfInterest = interest
        }

        view.bringSubviewToFront(guideView)
        view.bringSubviewToFront(closeButton)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              first.type == .qr,
              let value = first.stringValue else { return }

        captureSession.stopRunning()
        HapticsHelper.successHaptic()
        dismiss(animated: true) { [weak self] in
            self?.onCodeScanned?(value)
        }
    }

    @objc private func closeTapped() {
        captureSession.stopRunning()
        dismiss(animated: true)
    }
}
