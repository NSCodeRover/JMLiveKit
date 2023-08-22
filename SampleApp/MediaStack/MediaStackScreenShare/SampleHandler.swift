//
//  SampleHandler.swift
//  MediaStackScreenShare
//
//  Created by Onkar Dhanlobhe on 21/06/23.
//

import ReplayKit
import CoreVideo
import JMMediaStackSDK
import MMWormhole


class SampleHandler: RPBroadcastSampleHandler {
    
    let screenShareBufferListen = MMWormhole(applicationGroupIdentifier: JMScreenShareManager.appGroupIdentifierEX, optionalDirectory: "wormhole")
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) { JMScreenShareManager.sendScrenshareState(.ScreenShareStateStarting)
        screenShareBufferListen.listenForMessage(withIdentifier: "StopScreen") { message in
            let userInfo = [NSLocalizedFailureReasonErrorKey: "failed to broadcast because...."]

            self.finishBroadcastWithError( NSError(domain: "ScreenShare", code: -1, userInfo: userInfo))
        }

    }
    override func broadcastPaused() {JMScreenShareManager.sendScrenshareState(.ScreenShareStatePause)}
    override func broadcastResumed() {JMScreenShareManager.sendScrenshareState(.ScreenShareStateResume)}
    override func broadcastFinished() {JMScreenShareManager.sendScrenshareState(.ScreenShareStateStopping)}
    override func finishBroadcastWithError(_ error: Error) {
        print(error)
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        
        switch sampleBufferType {
            
        case RPSampleBufferType.video:
            JMScreenShareManager.sendSampleBuffer(sampleBuffer)
            break
            
        case RPSampleBufferType.audioApp:
            break
        case RPSampleBufferType.audioMic:
            break
        @unknown default:
            fatalError("Unknown type of sample buffer")
        }
    }
}
