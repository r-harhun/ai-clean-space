//
//  ContentView.swift
//  ai-clean-space
//
//  Created by Mikita on 18.09.25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingShown") var onboardingShown: Bool = false
      
      var body: some View {
          if onboardingShown {
              AICleanSpaceView()
          } else {
              OnboardingView()
          }
      }
}
