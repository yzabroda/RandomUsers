//
//  UserDetailsView.swift
//  RandomUsers
//
//  Created by Yuriy Zabroda on 07.07.2021.
//

import SwiftUI




struct UserDetailsView: View {
    let user: User

    var body: some View {
        VStack {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
            Button {
                PersistenceController.shared.updateAvatar(forUser: user) {
                    self.image = user.avatarImage
                }
            } label: {
                Text("Change Avatar")
            }

            Text("First Name: \(user.firstName!)")
            Text("Last Name: \(user.lastName!)")
            Text("Phone: \(user.phoneNumber!)")
            Text("Credid Card: \(user.creditCard!)")
            Text("Payment Method: \(user.paymentMethod!)")
        }
        .navigationTitle(user.username!)
        .onAppear {
            self.image = user.avatarImage
        }
    }

    @State private var image = Image(systemName: "lasso")
}





struct UserDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        UserDetailsView(user: User())
    }
}
