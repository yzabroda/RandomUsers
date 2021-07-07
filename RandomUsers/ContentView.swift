//
//  ContentView.swift
//  RandomUsers
//
//  Created by Yuriy Zabroda on 07.07.2021.
//

import SwiftUI
import CoreData




/**

 Represents "master" view which contains a table with rows
 (containing user's country avatar and username) and a "+" button.

 Tapping the "+" button will create a new user and add them to the list.

 */
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \User.timestamp, ascending: true)],
        animation: .default)
    private var users: FetchedResults<User>

    var body: some View {
        NavigationView {
            List {
                ForEach(users) { user in
                    NavigationLink(destination: UserDetailsView(user: user)) {
                        HStack {
                            user.avatarImage
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: rowHeight)
                            Text(user.username!)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(SidebarListStyle())  // Supporting modern "sidebar" UI on iPad.
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }


    private func addItem() {
        withAnimation {
            PersistenceController.shared.fetchRandomUser()
        }
    }


    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { users[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }


    private let rowHeight: CGFloat = 44
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}



extension User {

    /**
     Converts raw `Data` representation of avatar image
     into SwiftUI `Image`.
     */
    var avatarImage: Image {
        guard let avatar = avatar else {
            return Image(systemName: "lasso")
        }

        guard let image = UIImage(data: avatar) else {
            return Image(systemName: "lasso")
        }

        return Image(uiImage: image)
    }
}
