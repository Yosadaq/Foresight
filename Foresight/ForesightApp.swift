//
//  ForesightApp.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/26/26.
//

import SwiftUI
import CoreData

@main
struct ForesightApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
