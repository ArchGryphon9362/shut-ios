//
//  ContentView.swift
//  asu-app
//
//  Created by ArchGryphon9362 on 25/09/2023.
//

import SwiftUI
import CoreBluetooth
import NavigationBackport

struct DiscoveryView: View {
    @EnvironmentObject var scooterManager: ScooterManager
    @State var forceNbCrypto: [UUID: Bool] = [:]
    #if !os(macOS)
    let haptics = UINotificationFeedbackGenerator()
    #endif
    
    var body: some View {
        VStack {
            NBNavigationStack {
                List(Array(scooterManager.discoveredScooters.values)) { scooter in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(scooter.name).bold().font(.title2).background(
                                NavigationLink("", destination: ScooterView(
                                    scooter: scooterManager.scooter,
                                    discoveredScooter: scooter,
                                    forceNbCrypto: forceNbCrypto[scooter.peripheral.identifier] ?? false
                                ).navigationTitle(scooter.name)).opacity(0)
                            )
                            Text(scooter.model.name)
                            if (scooter.mac != "") {
                                Text(scooter.mac)
                            }
                            Text("RSSI: \(scooter.rssi)dB")
                        }
                        Spacer()
                        VStack {
                            Image(scooter.model.image)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                            if forceNbCrypto[scooter.peripheral.identifier] ?? false {
                                Text("Forcing NBCrypto").foregroundColor(.red).font(.footnote)
                            }
                        }.frame(height: 80)
                    }.contextMenu(menuItems: {
                        var forceValue = forceNbCrypto[scooter.peripheral.identifier] ?? false
                        
                        Button {
                            forceValue.toggle()
                            forceNbCrypto[scooter.peripheral.identifier] = forceValue
                            #if !os(macOS)
                            haptics.notificationOccurred(forceValue ? .success : .warning)
                            #endif
                        } label: {
                            Label("Force NinebotCrypto", systemImage: forceValue ? "checkmark.circle.fill" : "x.circle")
                        }
                    })
                }
                .listStyle(.inset)
                .navigationTitle("Pick your scooter")
            }
        }
    }
}
