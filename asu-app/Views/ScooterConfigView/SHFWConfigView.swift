//
//  SHFWConfigView.swift
//  asu-app
//
//  Created by ArchGryphon9362 on 01/10/2023.
//

import SwiftUI
import NavigationBackport

private struct ProfileOptionsView: View {
    @Binding var selectedProfile: Int
    
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Editing Profile")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Picker("", selection: self.$selectedProfile) {
                    Text("1").tag(0)
                    Text("2").tag(1)
                    Text("3").tag(2)
                }.pickerStyle(.segmented)
            }
        }
    }
}

private struct ThrottleSelectionView: View {
    @Binding var throttleCurve: Int
    
    var body: some View {
        Picker("", selection: self.$throttleCurve) {
            Text("Eco").tag(0)
            Text("Drive").tag(1)
            Text("Sports").tag(2)
        }.pickerStyle(.segmented)
    }
}

private struct SpeedLimitView: View {
    @Binding var speedLimit: Int
    @Binding var speedBased: Bool
    
    var body: some View {
        let minSpeedLimit: Float = self.speedBased ? 1 : 0
        ReleaseSlider(
            name: "Speed Limit",
            value: self.$speedLimit,
            in: minSpeedLimit...65,
            unit: "km/h",
            step: 1,
            mapping: [
                0: "Off"
            ]
        )
    }
}

private struct ThrottleModeView: View {
    @Binding var speedLimit: Int
    @Binding var speedBased: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Throttle Mode")
                .font(.footnote)
                .foregroundColor(.secondary)
            Picker("", selection: self.$speedBased) {
                Text("Speed Based")
                    .tag(true)
                    .disabled(self.speedLimit == 0)
                Text("Power Based (DPC)")
                    .tag(false)
            }
            .pickerStyle(.segmented)
            .disabled(self.speedLimit == 0 && !self.speedBased)
        }
    }
}

private struct CurveView: View {
    @Binding var curve: [Float]
    
    var body: some View {
        ReleaseSlider(name: "Point 1", value: self.$curve[0], in: 0...100, unit: "A", step: 0.01)
        ReleaseSlider(name: "Point 2", value: self.$curve[1], in: 0...100, unit: "A", step: 0.01)
        ReleaseSlider(name: "Point 3", value: self.$curve[2], in: 0...100, unit: "A", step: 0.01)
        ReleaseSlider(name: "Point 4", value: self.$curve[3], in: 0...100, unit: "A", step: 0.01)
    }
}

private struct ProfileConfigView: View {
    @ObservedObject var profile: ScooterManager.SHFWProfile
    
    @State private var throttleCurve = 0
    
    var body: some View {
        // TODO: DisclosureGroup? would need to make indentation not ugly...
        // TODO: using listRowSeparator's would be nice, but iOS 15+
        Section(header: Text("Throttle")) {
            ThrottleSelectionView(throttleCurve: self.$throttleCurve)
            SpeedLimitView(
                speedLimit: self.getSmoothness(self.throttleCurve).speedLimit,
                speedBased: self.getSpeedBased(self.throttleCurve)
            )
            ThrottleModeView(
                speedLimit: self.getSmoothness(self.throttleCurve).speedLimit,
                speedBased: self.getSpeedBased(self.throttleCurve)
            )
            if !self.getSpeedBased(self.throttleCurve).wrappedValue {
                CurveView(curve: self.getCurve(self.throttleCurve))
            } else {
                ReleaseSlider(name: "Power Limit", value: self.getCurve(self.throttleCurve)[3], in: 0...100, unit: "A", step: 0.01)
                ReleaseSlider(name: "Current Smoothness", value: self.getSmoothness(self.throttleCurve).smoothness, in: 0...2500, unit: "mA", step: 100)
            }
        }
        
        Section(header: Text("Brake")) {
            CurveView(curve: self.$profile.brakeAmps)
        }
    }
    
    private func getCurve(_ curveNumber: Int) -> Binding<[Float]> {
        [
            self.$profile.ecoAmps,
            self.$profile.driveAmps,
            self.$profile.sportsAmps
        ][curveNumber]
    }
    
    private func getSmoothness(_ curveNumber: Int) -> Binding<SHFWMessage.SpeedBasedConfig> {
        [
            self.$profile.ecoSmoothness,
            self.$profile.driveSmoothness,
            self.$profile.sportsSmoothness
        ][curveNumber]
    }
    
    private func getSpeedBased(_ curveNumber: Int) -> Binding<Bool> {
        [
            self.$profile.booleans.ecoSpeedBased,
            self.$profile.booleans.driveSpeedBased,
            self.$profile.booleans.sportsSpeedBased
        ][curveNumber]
    }
}

private struct SystemConfigView: View {
    @ObservedObject var global: ScooterManager.SHFWGlobal
    
    var body: some View {
        Section(header: Text("System Settings")) {
            // pwm
            ReleaseSlider(name: "PWM", value: self.$global.pwm, in: 4...24, step: 4)
        }
    }
}

struct SHFWConfigView: View {
    @ObservedObject var shfw: ScooterManager.SHFW

    @State private var selectedProfile: Int = 0
    
    var body: some View {
        VStack {
            if let config = self.shfw.config {
                NBNavigationStack {
                    List {
                        NavigationLink("Profile Settings") {
                            List {
                                ProfileOptionsView(selectedProfile: self.$selectedProfile)
                                ProfileConfigView(profile: config.getProfile(self.selectedProfile))
                            }
                            .navigationTitle("Profile Settings")
                            .navigationBarTitleDisplayMode(.large)
                        }
                        NavigationLink("System Settings") {
                            List {
                                SystemConfigView(global: config.global)
                            }
                            .navigationTitle("System Settings")
                            .navigationBarTitleDisplayMode(.large)
                        }
                    }
                }
            } else if self.shfw.installed == true {
                HStack {
                    ProgressView()
                    Text("Loading SHFW config")
                }
            } else {
                Text("Dear hyuman, we do not have the kinds of resources needed to switch you back to the tab you came from, and the popup doing that for us appears to have not shown. Kindly go back to the previous tab as this one is empty :(").padding()
            }
        }
    }
}
