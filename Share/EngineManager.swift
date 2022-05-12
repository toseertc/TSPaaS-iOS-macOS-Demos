//
//  EngineManager.swift
//  macOSDemo
//
//  Created by yxibng on 2021/1/6.
//

#if os(iOS)
import UIKit
import TSRtc_iOS
#endif

#if os(OSX)
import Cocoa
import TSRtc_macOS
#endif

func runOnMainThread(_ work: @escaping ()->()) {
    if Thread.isMainThread {
        work()
    } else {
        DispatchQueue.main.async(execute: DispatchWorkItem.init(block: {
            work()
        }))
    }
}

@objc protocol EngineManagerDelegate {
    @objc optional func shouldHandleInvalidChannelId()
    @objc optional func shouldHandleInvalidUid()
    @objc optional func shouldHandleJoinError(code: Int, message: String?)
    @objc optional func shouldHandleJoinSuccess()
    @objc optional func shouldHandleKickOff()
    @objc optional func shouldHandleConnectLost()
    @objc optional func shouldHandleServiceStopped()
    @objc optional func shouldHandleOnLeaveChannleSuccess()
    @objc optional func shouldHandleSwitchDualStreamFailed(code: Int, message: String?)
    @objc optional func shouldHandleDeviceNoPermission()
}



class EngineManager: NSObject {
    
    static let sharedEngineManager: EngineManager = EngineManager()
    var rtcEngine: TSRtcEngineKit!
    var rtcChannel: TSRtcChannel?
    
    let chatManager = VideoChatManager.init()
    weak var delegate: EngineManagerDelegate?
    
    var channelId: String?
    
    override init() {
        super.init()
        
        let config = TSRtcEngineConfig.init()
        config.codecPriority = .hardware
        config.appId = kAppId
        rtcEngine = TSRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        //设置编码参数
        let encodeConfig = TSVideoEncoderConfiguration.init()
        encodeConfig.dimensions = TSVideoDimension640x480
        encodeConfig.frameRate = TSVideoFrameRate.fps15.rawValue
        encodeConfig.orientationMode = .fixedLandscape
        encodeConfig.mirrorMode = .auto
        
        rtcEngine.setVideoEncoderConfiguration(encodeConfig)
        rtcEngine.setLocalRenderMode(.fit, mirrorMode: .auto)
        
        rtcEngine.enableDualStreamMode(true)
    }
    
    func createChannel(channelId: String) -> Bool {
        self.rtcChannel = self.rtcEngine.createRtcChannel(channelId, profile: .liveBroadcasting, delegate: self)
        self.rtcChannel?.setClientRole(.audience)
        return self.rtcChannel != nil
    }
    
    func destroyChannel() {
        self.rtcChannel?.destroy()
        self.rtcChannel = nil
        /*
         清理所有的数据
         */
        self.chatManager.localLeavel()
    }
    
    func joinChannel(by uid: String) -> Bool {
        guard let ret = self.rtcChannel?.join(byUid: uid) else {
            return false
        }
        if ret == TSErrorCode.invalidArgument.rawValue * -1 {
            /*
             进入频道失败
             用户 ID 非法
             */
            runOnMainThread {
                self.delegate?.shouldHandleInvalidUid?()
            }
            return false
        }
        return true
    }
    
    func leaveChannel() {
        self.rtcChannel?.leave()
    }
    
    
    func enableLocalAudio(enable: Bool) {
        self.rtcEngine.enableLocalAudio(enable)
    }
    func enableLocalVideo(enable: Bool)  {
        self.rtcEngine.enableLocalVideo(enable)
    }
    
    func setupLocalVideoCanvas(_ canvas: TSRtcVideoCanvas) {
        self.rtcEngine.setupLocalVideo(canvas)
    }
    
    func setupRemoteVideoCanvas(_ canvas: TSRtcVideoCanvas)  {
        self.rtcChannel?.setupRemoteVideo(canvas)
    }
    
    func muteRemoteAudio(uid: String, mute: Bool)  {
        self.rtcChannel?.muteRemoteAudioStream(uid, mute: mute)
    }
    
    func muteRemoteVideo(uid: String, mute: Bool)  {
        self.rtcChannel?.muteRemoteVideoStream(uid, streamName: "", mute: mute)
    }
    
    func publish() {
        self.rtcChannel?.publish()
    }
    
    func unpublish()  {
        self.rtcChannel?.unpublish()
    }

#if os(OSX)
    
    func allCameras() -> [TSRtcDeviceInfo] {
        return self.rtcEngine.enumerateDevices(.videoCapture) ?? []
    }
    
    func allMicrophone() -> [TSRtcDeviceInfo] {
        return self.rtcEngine.enumerateDevices(.audioRecording) ?? []
    }
    
    func allSpeakers() -> [TSRtcDeviceInfo] {
        return self.rtcEngine.enumerateDevices(.audioPlayout) ?? []
    }
    
    func changeDevice(id: String, type: TSMediaDeviceType) {
        self.rtcEngine.setDevice(type, deviceId: id)
    }
    
    func currentDevice(type: TSMediaDeviceType) -> TSRtcDeviceInfo? {
        return self.rtcEngine.getDeviceInfo(type)
    }
    
#endif
    
#if os(iOS)
    
    func switchCamera() -> Int{
        return Int(self.rtcEngine.switchCamera())
    }
    
#endif
    func switchDualSteam(uid: String, to high: Bool) {
        let type = high ? TSVideoStreamType.high : TSVideoStreamType.low
        self.rtcChannel?.setRemoteVideoStreamTypeForUser(uid, streamName: nil, streamType: type)
        /*
        1. 大小流切换没有回调
        2. 如果切换失败，会有warning 抛出
        3. 切换之后，默认切换成功，记录一下状态
         */
        self.chatManager.remoteVideoDualStreamChange(uid: uid, high: high)
    }    
}

extension EngineManager: TSRtcEngineDelegate {
    
    func rtcEngine(_ engine: TSRtcEngineKit, didOccurError errorCode: Int32, message: String) {
        if errorCode == TSErrorCode.invalidChannelId.rawValue {
            /*
             创建频道失败，
             channelId 非法
             */
            runOnMainThread {
                self.delegate?.shouldHandleInvalidChannelId?()
            }
        }
    }
    
    func rtcEngine(_ engine: TSRtcEngineKit, localAudioStateChange state: TSLocalAudioState, error: TSLocalAudioError) {
                
        switch state {
        case .stopped, .failed:
            print("local audio stoped")
            if error == .deviceNoPermission {
                print("error, local audio has no permission to start")
                runOnMainThread {
                    self.delegate?.shouldHandleDeviceNoPermission?()
                }
            }
        case .recording:
            print("local audio start recording")
        case .sending:
            print("local audio is sending to remote")
        case .noSend:
            print("local user choose not to send audio to remote")
        @unknown default:
            fatalError()
        }
    }
    
    func rtcEngine(_ engine: TSRtcEngineKit, localVideoStateChange state: TSLocalVideoStreamState, error: TSLocalVideoStreamError) {
        
        switch state {
        case .stopped, .failed:
            print("local video stoped")
            if error == .deviceNoPermission {
                print("error, local video has no permission to start")
                runOnMainThread {
                    self.delegate?.shouldHandleDeviceNoPermission?()
                }
            }
        case .capturing:
            print("local video start recording")
        case .sending:
            print("local video is sending to remote")
        case .noSend:
            print("local user choose not to send video to remote")
        @unknown default:
            fatalError()
        }
    }
}

extension EngineManager: TSRtcChannelDelegate {
    
    func rtcChannel(_ rtcChannel: TSRtcChannel, didOccurError errorCode: Int32, message: String) {
        
        if errorCode >= TSErrorCode.lookupScheduleServerFailed.rawValue &&
            errorCode <= TSErrorCode.noAvailableServerResources.rawValue ||
            errorCode == TSErrorCode.invalidAppId.rawValue {
            runOnMainThread {
                //join channel, but occur error, should leave
                self.delegate?.shouldHandleJoinError?(code: Int(errorCode), message: message)
            }
        }
    }
        
    func rtcChannel(_ rtcChannel: TSRtcChannel, didOccurWarning warningCode: Int32, message: String) {
    
        if warningCode >= TSWarningCode.vpmDualNoLowStream.rawValue &&
            warningCode <= TSWarningCode.vpmDualSwitchHighFailed.rawValue {
            //TODO: switch dual stream failed
            runOnMainThread {
                self.delegate?.shouldHandleSwitchDualStreamFailed?(code: Int(warningCode), message: message)
            }
        }
    }
    
    func rtcChannel(_ rtcChannel: TSRtcChannel, didJoinChannelWithUid uid: String, elapsed: Int) {
        runOnMainThread {
            self.chatManager.localJoin(uid: uid)
            self.delegate?.shouldHandleJoinSuccess?()
        }
    }

    func rtcChannel(_ rtcChannel: TSRtcChannel, didLeaveChannelWith stats: TSChannelStats) {
        runOnMainThread {
            self.delegate?.shouldHandleOnLeaveChannleSuccess?()
        }
    }
    
    
    func rtcChannel(_ rtcChannel: TSRtcChannel, didJoinedOfUid uid: String, elapsed: Int) {
        runOnMainThread {
            self.chatManager.remoteJoin(uid: uid)
        }
    }
    
    func rtcChannel(_ rtcChannel: TSRtcChannel, didOfflineOfUid uid: String, reason: TSUserOfflineReason) {
        runOnMainThread {
            self.chatManager.remoteLeave(uid: uid)
        }
    }
    
    
    func rtcChannel(_ rtcChannel: TSRtcChannel, onAudioSubscribeStateChangedOf uid: String, newState state: TSStreamSubscribeState, elapsed: Int) {
        
        
        if state == .online {
            runOnMainThread {
                self.chatManager.remoteAudioOnlineStateChange(uid: uid, online: true)
            }
            return
        }
        
        if state == .offline {
            runOnMainThread {
                self.chatManager.remoteAudioOnlineStateChange(uid: uid, online: false)
            }
            return
        }
        
        if state == .noRecv {
            runOnMainThread {
                self.chatManager.remoteAudioNoReceiveStateChange(uid: uid, mute: true)
            }
            return
        }
        
        if state == .noSend {
            runOnMainThread {
                self.chatManager.remoteAudioSendStateChange(uid: uid, state: false)
            }
            return
        }
        
        
        if [TSStreamSubscribeState.subscribing,
            TSStreamSubscribeState.subscribed,
            TSStreamSubscribeState.frozen].contains(state) {
            
            runOnMainThread {
                self.chatManager.remoteAudioNoReceiveStateChange(uid: uid, mute: false)
                self.chatManager.remoteAudioSendStateChange(uid: uid, state: true)
            }
        }
        
    }
    
    func rtcChannel(_ rtcChannel: TSRtcChannel, onVideoSubscribeStateChangedOf uid: String, streamName: String, newState state: TSStreamSubscribeState, elapsed: Int) {
        
        if state == .online {
            runOnMainThread {
                self.chatManager.remoteVideoOnlineStateChange(uid: uid, online: true)
            }
            return
        }
        
        if state == .offline {
            runOnMainThread {
                self.chatManager.remoteVideoOnlineStateChange(uid: uid, online: false)
            }
            return
        }
        
        if state == .noRecv {
            runOnMainThread {
                self.chatManager.remoteVideoNoReceiveStateChange(uid: uid, mute: true)
            }
            return
        }
        
        if state == .noSend {
            runOnMainThread {
                self.chatManager.remoteVideoSendStateChange(uid: uid, state: false)
            }
            return
        }
        
        
        if [TSStreamSubscribeState.subscribing,
            TSStreamSubscribeState.subscribed,
            TSStreamSubscribeState.frozen].contains(state) {
            
            runOnMainThread {
                self.chatManager.remoteVideoNoReceiveStateChange(uid: uid, mute: false)
                self.chatManager.remoteVideoSendStateChange(uid: uid, state: true)
            }
        }
        
        
    }
    
    
    func rtcChannel(_ rtcChannel: TSRtcChannel, connectionChangedTo state: TSConnectionStateType, reason: TSConnectionChangedReason) {
    
        if state == .failed {
            
            if reason == .changedRejectedByServer {
                //kicked off
                runOnMainThread {
                    self.delegate?.shouldHandleKickOff?()
                }
                 return
            }
            
            /*
             重连20分钟没有连上，需要退出频道
             */
            runOnMainThread {
                self.delegate?.shouldHandleServiceStopped?()
            }
            return
        }

    }
    
    func rtcChannelConnectionDidLost(_ rtcChannel: TSRtcChannel) {
        runOnMainThread {
            self.delegate?.shouldHandleConnectLost?()
        }
    }
        
}




