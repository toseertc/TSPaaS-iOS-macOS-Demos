//
//  VideoChatItem.swift
//  macOSDemo
//
//  Created by yxibng on 2021/1/6.
//

#if os(iOS)
import UIKit
import TSRtc_iOS

typealias VIEW_CLASS = UIView
#endif

#if os(OSX)
import Cocoa
import TSRtc_macOS

typealias VIEW_CLASS = NSView
#endif



class VideoChatItem: NSObject {

    class StreamState {
        var online = false
        var remoteNoSend = true
        var noReceive = false
    }
    
    class VideoStreamState : StreamState{
        var isHD = true
    }

    var uid: String = ""
    var isLocal: Bool = false
    var isFront:Bool! = true
    
    
    let audioState = StreamState()
    let videoState = VideoStreamState()
    
    //video canvas
    let canvas: TSRtcVideoCanvas = {
        let canvas = TSRtcVideoCanvas.init()
        canvas.view = VIEW_CLASS.init()
        canvas.mirrorMode = .auto
        canvas.renderMode = .fit
        return canvas
    }()
    
    
    func addCanvsTo(view: VIEW_CLASS) {
        
        if !self.videoState.online {
            view.subviews.forEach { $0.removeFromSuperview() }
            return
        }
        
        view.subviews.forEach { $0.removeFromSuperview() }
        let canvas = TSRtcVideoCanvas.init()
        canvas.view = UIView()
        canvas.uid = self.uid
        canvas.mirrorMode = .auto
        canvas.renderMode = .fit
        view.addSubview(canvas.view!)
        EngineManager.sharedEngineManager.rtcChannel?.setupRemoteVideo(canvas)
        guard let canvasView = canvas.view else  {
            return
        }
        
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        let left = NSLayoutConstraint.init(item: canvasView, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: 0)
        let rigth = NSLayoutConstraint.init(item: canvasView, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: 0)
        let top = NSLayoutConstraint.init(item: canvasView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 0)
        let bottom = NSLayoutConstraint.init(item: canvasView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: 0)
        view.addConstraints([left, rigth, top, bottom])
        
    }
    
}
