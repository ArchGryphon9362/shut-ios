// Thanks to Basse for providing the beacon parsing code and all the models
//
//  Scooter.swift
//  asu-app
//
//  Created by ArchGryphon9362 on 25/09/2023.
//

import Foundation
import OrderedCollections
import CoreBluetooth

class Scooter : Observable, ScooterBluetoothDelegate {
    private var forceNbCrypto: Bool = false
    private var scooterBluetooth: ScooterBluetooth = .init()
    private var scooterCrypto: ScooterCrypto = .init()
    private var messageManager: RawMessageManager = .init(scooterProtocol: .ninebot(true))
    private var scooterRemover: [UUID: Timer] = [:]
    
    @Published var discoveredScooters: OrderedDictionary<UUID, DiscoveredScooter> = [:]
    
    var authenticating: Bool = false
    var model: ScooterModel? = nil
    var connectionState: ConnectionState = .disconnected
    
    init() {
        self.scooterBluetooth.setScooterBluetoothDelegate(self)
    }
    
    func connectTo(discoveredScooter: DiscoveredScooter, forceNbCrypto: Bool = false) {
        let name = discoveredScooter.name
        let scooterProtocol = discoveredScooter.model.scooterProtocol(forceNbCrypto: forceNbCrypto)
        
        self.model = discoveredScooter.model
        self.forceNbCrypto = forceNbCrypto
        self.scooterCrypto.setName(name)
        self.scooterCrypto.setProtocol(scooterProtocol)
        self.messageManager = .init(scooterProtocol: scooterProtocol)
        scooterBluetooth.connect(discoveredScooter.peripheral, name: name, scooterProtocol: scooterProtocol)
    }
    
    // TODO: add "updateUi" back
    func disconnectFromScooter() {
        scooterBluetooth.disconnect(nil)
    }
    
    func writeRaw(_ data: Data, characteristic: WriteLoop.WriteCharacteristic, writeType: WriteLoop.WriteType) {
        self.scooterBluetooth.write(writeType: writeType, characteristic: characteristic) {
            var data = data
            if characteristic == .serial, self.model?.scooterProtocol(forceNbCrypto: self.forceNbCrypto).crypto == true {
                data = self.scooterCrypto.encrypt(data)
            }
            return data
        }
    }
    
    // underlying ScooterBluetooth methods
    func scooterBluetooth(_ scooterBluetooth: ScooterBluetooth, didDiscover scooter: DiscoveredScooter, forIdentifier identifier: UUID) {
        if let oldScooter = self.discoveredScooters[identifier] {
            if scooterCrypto.awaitingButtonPress && oldScooter.serviceData != scooter.serviceData {
                self.connectTo(discoveredScooter: scooter)
            }
        }
        
        self.discoveredScooters[identifier] = scooter
        self.scooterRemover[identifier]?.invalidate()
        self.scooterRemover[identifier] = Timer.scheduledTimer(withTimeInterval: advertisementTimeout, repeats: false) { _ in
            self.discoveredScooters.removeValue(forKey: identifier)
        }
    }
    
    func scooterBluetoothDidUpdateState(_ scooterBluetooth: ScooterBluetooth) {
        let connectionState = self.scooterBluetooth.connectionState
        self.connectionState = connectionState
        self.authenticating = self.authenticating || connectionState == .authenticating
        
        switch(connectionState) {
        case .disconnected:
            if !self.scooterBluetooth.blockDisconnectUpdates {
                self.authenticating = false
                self.model = nil
                self.connectionState = .disconnected
                
                self.scooterCrypto.reset()
            }
        case .ready:
            if !self.scooterCrypto.authenticated {
                self.scooterCrypto.startAuthenticating(withScooter: self)
            }
        case .connected:
            // TODO: start collecting info and whatnot
            break
        default: return
        }
    }
    
    func scooterBluetooth(_ scooterBluetooth: ScooterBluetooth, didReceive data: Data, forCharacteristic uuid: CBUUID) {
        var data = data
        if uuid == serialRXCharUUID {
            guard let decryptedData = self.scooterCrypto.decrypt(data) else {
                return
            }
            data = decryptedData
        }
        
        if !self.scooterCrypto.authenticated {
            let connectionState = self.scooterCrypto.continueAuthenticating(withScooter: self, received: data, forCharacteristic: uuid)
            if let connectionState = connectionState {
                scooterBluetooth.setConnectionState(connectionState)
            }
            return
        }
        
        let parsedData = self.messageManager.ninebotParse(data)
        // TODO: do something with the parsed data
    }
}

