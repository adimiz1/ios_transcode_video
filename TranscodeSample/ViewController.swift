//
//  ViewController.swift
//  TranscodeSample
//
//  Created by Adi Mizrahi on 04/07/2024.
//

import UIKit
import Cloudinary
import AVKit
class ViewController: UIViewController {

    var cloudinary: CLDCloudinary!

    override func viewDidLoad() {
        super.viewDidLoad()
        cloudinary = CLDCloudinary(configuration: CLDConfiguration(cloudName: "adimizrahi2", secure: true))
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        transcodeVideo()
    }

    func transcodeVideo() {
        guard let sportVideoURL = Bundle.main.url(forResource: "sport", withExtension: "mp4") else {
            print("Failed to find sport.mp4 in the bundle.")
            return
        }
        let videoTranscode = VideoTranscode(sourceURL: sportVideoURL)

        // Set the desired output format and dimensions
        videoTranscode.setOutputFormat(format: .mov)
        videoTranscode.setOutputDimensions(dimensions: CGSize(width: 320, height: 480)) // Set your desired dimensions here
        videoTranscode.setCompressionPreset(preset: AVAssetExportPresetHighestQuality)

        // Perform the transcode
        videoTranscode.transcode { success, error in
            if success {
                if let outputURL = videoTranscode.outputURL {
                    print("Transcoding completed successfully. Output URL: \(outputURL)")
                    self.uploadToCloudinary(videoTranscode.outputURL)
                    // You can use the outputURL here, for example, play the video or upload it to a server
                }
            } else {
                if let error = error {
                    print("Transcoding failed with error: \(error.localizedDescription)")
                } else {
                    print("Transcoding failed with unknown error.")
                }
            }
        }

    }

    func uploadToCloudinary(_ url: URL?) {
        guard let url = url else {
            return
        }
        let options = CLDUploadRequestParams()
        options.setResourceType("video")
        cloudinary.createUploader().upload(url: url, uploadPreset: "ios_sample", params: options, completionHandler:  { response, error in
            if let error = error {
                print("Upload error: \(error)")
            }
            print(response?.secureUrl)
        })

    }


}

