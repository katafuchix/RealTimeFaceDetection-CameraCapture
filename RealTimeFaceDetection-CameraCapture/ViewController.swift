//
//  ViewController.swift
//  RealTimeFaceDetection-CameraCapture
//
//  Created by cano on 2019/06/11.
//  Copyright © 2019 deskplate. All rights reserved.
//

import UIKit
import AVKit
import Vision
import RxSwift
import RxCocoa
import NSObject_Rx
import PinLayout

class ViewController: UIViewController {

    @IBOutlet weak var captureView: UIView!
    var captureSession : AVCaptureSession!
    var previewLayer : AVCaptureVideoPreviewLayer!
    
    private lazy var drawLine : UIView = {
        let view = UIView()
        view.layer.borderColor = UIColor.blue.cgColor
        view.layer.borderWidth = 5
        view.backgroundColor = UIColor.white
        view.alpha = 0.3
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.setUpViews()
        self.setUpCapture()
    }

    // キャプチャ領域の整理
    func setUpViews() {
        self.captureView.pin
            .top(self.view.pin.safeArea.top + 120)
            .left(self.view.pin.safeArea.left + 20)
            .right(self.view.pin.safeArea.right + 20)
            .bottom(self.view.pin.safeArea.bottom + 120)
    }
    
    // カメラでのキャプチャ準備
    func setUpCapture() {
        // ビデオで撮影したものをセッションに出力するように設定
        self.captureSession = AVCaptureSession()
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        captureSession.startRunning()
        
        // 画面に表示
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer.frame = self.captureView.frame
        self.view.layer.addSublayer(previewLayer)
        
        // カメラでのキャプチャ開始 delegateで出力処理を行う
        let captureFrame = AVCaptureVideoDataOutput()
        captureFrame.setSampleBufferDelegate(self, queue: DispatchQueue(label: "captureFrame"))
        self.captureSession.addOutput(captureFrame)
    }

    // 処理結果で得られたRect情報を表示対象のViewに対してのRectに変換
    func transformRect(fromRect: CGRect , toViewRect :UIView) -> CGRect {
        var toRect = CGRect()
        toRect.size.width = fromRect.size.width * toViewRect.frame.size.width
        toRect.size.height = fromRect.size.height * toViewRect.frame.size.height
        toRect.origin.y =  (toViewRect.frame.height) - (toViewRect.frame.height * fromRect.origin.y )
        toRect.origin.y  = toRect.origin.y -  toRect.size.height
        toRect.origin.x =  fromRect.origin.x * toViewRect.frame.size.width
        return toRect
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // 出力時の処理
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 出力バッファから画像バッファを取得
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
        
        // 画像処理リクエスト生成
        let request = VNDetectFaceRectanglesRequest { [unowned self] (response, err) in
            // 処理結果
            guard let observations = response.results as? [VNFaceObservation] else {return}
            DispatchQueue.main.async {
                for face in observations{
                    // captureViewが更新され続けるのでself.viewに対してのRectで考える
                    self.drawLine.frame = self.transformRect(fromRect: face.boundingBox, toViewRect: self.view)
                    self.view.addSubview(self.drawLine)
                }
            }
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics:camData]
        }
        // ハンドラの生成と実行
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
        try? handler.perform([request])
    }
}

