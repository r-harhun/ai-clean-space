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
