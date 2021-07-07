//
//  RandomUsersApp.swift
//  RandomUsers
//
//  Created by Yuriy Zabroda on 07.07.2021.
//

import SwiftUI

@main
struct RandomUsersApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
