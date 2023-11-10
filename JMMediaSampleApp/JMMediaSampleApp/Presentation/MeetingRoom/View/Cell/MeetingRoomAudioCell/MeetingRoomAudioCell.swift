//
//  MeetingRoomAudioCell.swift
//  MediaStack
//
//  Created by Atinderpal Singh on 28/02/23.
//

import UIKit
import WebRTC
import JMMediaStackSDK

class MeetingRoomAudioCell: UICollectionViewCell {
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var audioLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setPeer(peer: JMUserInfo) {
        
        self.textLabel.text = peer.name
        self.audioLabel.textColor = peer.hasAudio ? UIColor.green : UIColor.red
        
        let attachment = NSTextAttachment()
        attachment.image = UIImage(named: "audio_Host_Active")
        attachment.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
        let attachmentStr = NSAttributedString(attachment: attachment)
        let myString = NSMutableAttributedString(string: "")
        myString.append(attachmentStr)
        audioLabel.attributedText = myString
    }
}
