//
//  ContentView.swift
//  Kuna
//
//  Created by Richard Annand on 15/08/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            // Text("Hello, world!")
            Text(String(localized: "contentView.helloWorld", comment: "Hello world text"))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
