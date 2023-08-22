//
//  MeetingRoomVideoCell.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 06/03/23.
//

import UIKit
import JMMediaStackSDK

class MeetingRoomVideoCell: UICollectionViewCell {
    @IBOutlet weak var remoteVideoBGView: UIView!
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var videoLabel: UILabel!
    @IBOutlet weak var audioLabel: UILabel!
    @IBOutlet weak var remoteInitialBGView: UIView!
    @IBOutlet weak var initialsLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setPeer(peer: JMUserInfo) {
        self.textLabel.text = peer.name
        self.audioLabel.textColor = peer.hasAudio ? UIColor.green : UIColor.red
        self.initialsLabel.isHidden = peer.hasVideo
        
        if peer.hasVideo{
            self.videoLabel.textColor = .green
            remoteVideoBGView.isHidden = false
            remoteInitialBGView.isHidden = true
            self.bringSubviewToFront(remoteVideoBGView)
        }
        else {
            self.videoLabel.textColor = .red
            self.initialsLabel.text = getInitials(from: peer.name)
            remoteVideoBGView.isHidden = true
            remoteInitialBGView.isHidden = false
            self.bringSubviewToFront(remoteInitialBGView)
        }
    }
    
    func getInitials(from fullName: String) -> String {
        let components = fullName.components(separatedBy: " ")
        let firstInitial = components.first?.first ?? Character("")
        if let lastInitial = components.last, !lastInitial.contains("(Guest)"), let lastChar = lastInitial.first{
            return "\(firstInitial)\(lastChar)"
        }
        return "\(firstInitial)"
    }
}
