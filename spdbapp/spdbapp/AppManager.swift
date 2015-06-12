//
//  AppManager.swift
//  spdbapp
//
//  Created by tommy on 15/5/11.
//  Copyright (c) 2015年 shgbit. All rights reserved.
//

import UIKit
import Foundation
import Alamofire

class Poller {
    var timer: NSTimer?
    
    func start(obj: NSObject, method: Selector,timerInter: Double) {
        stop()
        
        //var time: Double = getSettingTime()
        timer = NSTimer(timeInterval: timerInter, target: obj, selector: method , userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
    }
    
    func stop() {
        if (isRun()){
            timer?.invalidate()
        }
    }
    
    func isRun() -> Bool{
        return (timer != nil && timer?.valid != nil)
    }
    
    //获取系统设置的时间   当前默认是3s
    func getSettingTime() -> NSTimeInterval {
        var filePath = NSBundle.mainBundle().pathForResource("TimeSettingConfig", ofType: "plist")
        var readData: NSMutableDictionary = NSMutableDictionary(contentsOfFile: filePath!)!
        //println("data = \(readData)")
        var time = readData.objectForKey("timeInterval")?.doubleValue
        return time!
    }
}


class AppManager : NSObject {
    
    dynamic var current : GBMeeting = GBMeeting()
    dynamic var netConnect: Bool = false
    dynamic var local = GBBox()
    
    var server = Server()
    
    var files: GBMeeting?
    
    var reqBoxURL: String?
    
    var count = 0
    var timerHearbeat = Poller()
    
    override init(){
        super.init()
        var filePath = NSHomeDirectory().stringByAppendingPathComponent("Documents/SettingsConfig.txt")
        
        var dict = NSMutableDictionary(contentsOfFile: filePath)!
        
        var ipStr = dict.objectForKey("txtBoxURL") as! String
        println("ip = \(ipStr)")
        
        
        server.showDetail()
        
        //配置url信息
        if (ipStr.isEmpty) {
            ipStr = server.defaultsIPStr()
        }else{
            ipStr = server.getIPStr()
        }
        
        reqBoxURL = server.boxServiceUrl
        
        //程序启动先创建Box
        local = createBox()
        
        //定时器每隔2s检测当前current是否发生变化
        var getCurrentPoller = Poller()
        getCurrentPoller.start(self, method: "getCurrent:", timerInter: 3.0)
        
        self.netConnect = false
   
        starttimer()
    }
    
    
    func starttimer(){
        //定时器每隔一段时间去检测当前联网状态
        timerHearbeat.start(self, method: "startHeartbeat:",timerInter: 3.0)
    }
    
    
    
    func startHeartbeat(timer: NSTimer){
        var url = server.heartBeatServiceUrl + GBNetwork.getMacId()
        Alamofire.request(.GET, url).responseJSON(options: NSJSONReadingOptions.MutableContainers) { (request, response, data, error) -> Void in
            
            if response?.statusCode == 200{
                self.netConnect = true
                self.count = 0
                println("netConnect ok,count = \(self.count)")
            }
            else{
                self.netConnect = false
                self.count++
                println("netConnect fail,count = \(self.count)")
                if self.count == 3{
                    println("netConnect daoshijian ,count = \(self.count)")
                    self.count = 0
                    timer.invalidate()
                }
            }
        }
        //MainViewController.checkstatus(MainViewController)
    }
    
    
    //register current ipad id to server，返回已经注册的id并保存
    func registerCurrentId(){
        let paras = ["id":GBNetwork.getMacId()]
        
        var id: NSString = ""
        Alamofire.request(.POST, reqBoxURL! ,parameters: paras, encoding: .JSON).responseJSON(options: NSJSONReadingOptions.MutableContainers) { (request,response, data, error) ->
        
        Void in
            println("post data = \(data!)")
            
            if(error != nil){
                NSLog("注册当前id失败，error ＝ %@", error!.description)
                return
            }
            
            //如果注册成功，则保存当前的iPad的id至../Documents/idData.txt 目录文件中
            if(response?.statusCode == 200){
                id = (data?.objectForKey("id")) as! NSString
                self.idInfoSave(id)
            }
        }
    }
    
    
    //保存当前iPad的id,只在注册成功的情况下才保存id，否则不保存
    func idInfoSave(id: NSString) {
        var idFilePath = NSHomeDirectory().stringByAppendingPathComponent("Documents/idData.txt")
        println("该id保存地址 = \(idFilePath)")
        
        var readData = NSData(contentsOfFile: idFilePath)
        var content = NSString(data: readData!, encoding: NSUTF8StringEncoding)!
        
        if(content == id){
            NSLog("当前ipad的id已保存")
            return
        }
        
        var b = id.writeToFile(idFilePath, atomically: true, encoding: NSUTF8StringEncoding, error: nil)
        if b {
            NSLog("当前ipad的id保存成功")
        }
        else{
            NSLog("当前ipad的id保存失败，请重新保存id")
        }
    }
    
    
    //读取本地iddata.txt文本文件记否存在，存在则返回true，否则返回false。
    func IsIdFileExist() -> Bool {
        var filePath = NSHomeDirectory().stringByAppendingPathComponent("Documents/idData.txt")
   
        //判断该文件是否存在，则创建该iddata. txt文件
        var manager = NSFileManager.defaultManager()
        if !manager.fileExistsAtPath(filePath){
            return false
        }
        return true
    }
    
    
    //根据id获取ipad所需信息
    func createBox() -> GBBox{
        
        var result = GBBox()
        var idstr = NSString()
        var b = IsIdFileExist()
        var filePath = NSHomeDirectory().stringByAppendingPathComponent("Documents/idData.txt")
        
        //如果iddata文件夹不存在，则创建iddata.txt文件
        if !b{
            var manager = NSFileManager.defaultManager()
            var bCreateFile = manager.createFileAtPath(filePath, contents: nil, attributes: nil)
            if bCreateFile{
                println("idData文件创建成功")
                //idstr = GBNetwork.getMacId()
            }
        }
        
        NSLog("filePath = %@", filePath)
        var readData = NSData(contentsOfFile: filePath)
        idstr = NSString(data: readData!, encoding: NSUTF8StringEncoding)! as NSString
        
        //如果不存在，则GBNetwork.getMacId()赋给id
        if (idstr.length <= 0){
            println("请重新注册id")
            self.registerCurrentId()
            idstr = GBNetwork.getMacId()
        }
        
        var urlString = "\(reqBoxURL!)?id=\(idstr)"
        NSLog("urlString = %@", urlString)
        
        getBoxResult { (boxResult) -> () in
            if let jsonResult: AnyObject = boxResult {
                println("result = \(jsonResult)")
                result.macId = jsonResult.objectForKey("id") as! String
                result.type = jsonResult.objectForKey("type") as? GBMeetingType
                result.name = jsonResult.objectForKey("name") as! String
            }
        }
       
        return result
    }
    
    
    func getBoxResult(completionHandler: (boxResult: AnyObject?) -> ()){
        var session = NSURLSession.sharedSession()
        var str = server.boxServiceUrl + "?id=" + GBNetwork.getMacId()
        var urlStr = NSURL(string: str)!
        let task = session.dataTaskWithURL(urlStr, completionHandler: { (data, response, err) -> Void in
            if err != nil{
                println("err = \(err.description)")
                return
            }
            var jsonResult: AnyObject = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: nil)!
            completionHandler(boxResult: jsonResult)
        })
        task.resume()
    }
    
    //将从服务器上读取的数据转换为GBMeetingType
    func EnumParser(enumStr: String) -> GBMeetingType {
        if enumStr == "dongshihui"{
            return GBMeetingType.DONGSHI
        }else if enumStr == "hangban"{
            return GBMeetingType.HANGBAN
        }else if enumStr == "dangzheng"{
            return GBMeetingType.DANGBAN
        }else if enumStr == "dangweihui"{
            return GBMeetingType.DANGWEI
        }else {
            return GBMeetingType.ALL
        }
    }
    
    
    
    
    //获取当前会议current
    func getCurrent(timer: NSTimer){
        //var router = Router.GetCurrentMeeting()
        var docPath = NSHomeDirectory().stringByAppendingPathComponent("Documents")
        
        var builder = Builder()
        
        Alamofire.request(.GET,server.meetingServiceUrl).responseJSON(options: NSJSONReadingOptions.MutableContainers) { (request, response, data, error) -> Void in
            if error != nil {
                //网络出错时调用LocalCreateMeeting 方法，从本地获取会议资料创建会议
                //println("error = \(error)")
                //println("会议信息将直接从本地读取，本地文件地址为\(docPath)")
                self.current = builder.LocalCreateMeeting()
                return
            }
            
            
            let json = JSON(data!)
            var id = json["_id"].stringValue
            
            if self.current.isEqual(nil)  {
                self.current = builder.CreateMeeting()
                
                DownLoadManager.isStart(true)
            }
            
            if(self.current.id == id) {
                return
            }
            
            self.current = builder.CreateMeeting()
            
            DownLoadManager.isStart(true)
        }
    }
    
    
    
    
    
}





