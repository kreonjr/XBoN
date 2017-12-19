//
//  XBOXMessager.swift
//  XbON
//
//  Created by Creon Creonopoulos on 3/11/17.
//  Copyright © 2017 Creon Creonopoulos. All rights reserved.
//

import Foundation

class XBOXMessager {
    struct PowerPacket {
        var live_id = ""
        private var power_payload:[UInt8] = [0x00]
        private var power_header:[UInt8] = [0xdd]
        
        init(liveId:String) {
            self.live_id = liveId
            power_payload.append(UInt8(self.live_id.count))
            power_payload.append(contentsOf:self.live_id.encode())
            power_payload.append(0)
            
            power_header.append(0x02)
            power_header.append(0x00)
            power_header.append(UInt8(power_payload.count))
            power_header.append(0x00)
            power_header.append(0x00)            
        }
        
        var powerPacket:[Byte] {
            get {
                return power_header + power_payload
            }
        }
    }
    
    let XBOX_PORT = 5050
    let XBOX_PING = "dd00000a000000000000000400000002"
    
    func powerOn(xboxIP:String, LiveID:String) -> [String:String] {
        let ip_addr = "\(xboxIP)"
        let live_id = LiveID.uppercased()

        
        var power_payload:[UInt8] = [0x00]
        power_payload.append(UInt8(live_id.count))
        power_payload.append(contentsOf:live_id.encode())
        power_payload.append(0x00)
        
        
        var power_header:[UInt8] = [0xdd]
        power_header.append(0x02)
        power_header.append(0x00)
        power_header.append(UInt8(power_payload.count))
        power_header.append(0x00)
        power_header.append(0x00)
        
        let power_packet:[Byte] = power_header + power_payload 
        let client = UDPClient(address: ip_addr, port: Int32(XBOX_PORT))
        sendPower(client: client, data: power_packet)
        var ping_result = sendPing(client: client)
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
            self.sendPower(client: client, data: power_packet)
        }
        
        if ping_result.isSuccess {
            client.close()
            return ["message":"Xbox Responded Succesfully"]
        }
        else {
            var count = 0

            while ping_result.isFailure {
                sendPower(client: client, data: power_packet)
                ping_result = sendPing(client: client)
                count += 1
                
                if count > 5 {
                    client.close()
                    return ["message":"Xbox Failed to respond"]
                }
            }
            
            client.close()
            return ["message":"Xbox Responded Succesfully"]
        }        
    }
    
    func sendPower(client:UDPClient, data:[Byte]) {
        for _ in 0...4 {
            _ = client.send(data: data)
            sleep(1)
        }
    }
    
    func sendPing(client:UDPClient) -> Result {
        return client.send(data:XBOX_PING.hexadecimal()!)
    }
}

extension String {
    func encode() -> [Byte] {
        return [Byte](self.utf8)
    }
    
    func hexadecimal() -> Data? {
        var data = Data(capacity: self.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, self.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else {
            return nil
        }
        
        return data
    }
}
