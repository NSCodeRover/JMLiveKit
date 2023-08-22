//
//  MeetingRoomShareVideoCell.swift
//  MediaStack
//
//  Created by Onkar Dhanlobhe on 28/06/23.
//

import UIKit
import WebRTC
import JMMediaStackSDK

class MeetingRoomShareVideoCell: UICollectionViewCell {

    @IBOutlet weak var remoteVideoBGView: UIView!
    @IBOutlet weak var textLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setPeer(peer: JMUserInfo) {
//        if let consumer = peer.consumerScreenShare {
//            consumer.track.isEnabled = true
//            DispatchQueue.main.async {
//                for view in self.remoteVideoBGView.subviews {
//                    view.removeFromSuperview()
//                }
//                let videoView = RTCMTLVideoView(frame: self.remoteVideoBGView.bounds)
//                videoView.contentMode = .scaleToFill
//                self.remoteVideoBGView.addSubview(videoView)
//                if let rtcVideoTrack = consumer.track as? RTCVideoTrack {
//                    rtcVideoTrack.add(videoView)
//                }
//                self.remoteVideoBGView.isHidden = false
//            }
//        }
    }
}
