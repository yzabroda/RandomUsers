//
//  Persistence.swift
//  RandomUsers
//
//  Created by Yuriy Zabroda on 07.07.2021.
//

import Combine
import CoreData
import os.log




class PersistenceController {

    static var shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = User(context: viewContext)
            newItem.username = "User"
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()


    let container: NSPersistentContainer


    init(inMemory: Bool = false, urlSession: URLSession = .shared) {
        container = NSPersistentContainer(name: "RandomUsers")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores() { storeDescription, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                Typical reasons for an error here include:
                * The parent directory does not exist, cannot be created, or disallows writing.
                * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                * The device is out of space.
                * The store could not be migrated to the current model version.
                Check the error message to determine what the actual problem was.
                */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        // !!!
        container.viewContext.automaticallyMergesChangesFromParent = true

        theURLSession = urlSession
    }


    final func fetchRandomUser() {
        randomUserSubscriber = randomUserPublisher
            .flatMap { randomUser in
                return self.avatarPublisher(with: randomUser)
            }
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    os_log("%{public}@", error.localizedDescription)
                }
            }, receiveValue: { randomUser in
                self.container.performBackgroundTask { backgroundContext in
                    let newUser = User(context: backgroundContext)

                    newUser.username = randomUser.username
                    newUser.firstName = randomUser.firstName
                    newUser.lastName = randomUser.lastName
                    newUser.country = randomUser.address.country
                    newUser.paymentMethod = randomUser.subscription.paymentMethod
                    newUser.creditCard = randomUser.creditCard.number
                    newUser.phoneNumber = randomUser.phoneNumber
                    newUser.avatar = randomUser.avatar

                    do {
                        try backgroundContext.save()
                    } catch {
                        os_log("%{public}@", error.localizedDescription)
                    }
                }
            })
    }


    final func updateAvatar(forUser user: User, completionHandler: @escaping () -> Void) {
        var trueRandomUser = RandomUser()
        trueRandomUser.address.country = user.country!

        updateAvatarSubscriber = avatarPublisher(with: trueRandomUser)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    os_log("%{public}@", error.localizedDescription)
                }
            }, receiveValue: { randomUser in
                self.container.performBackgroundTask { backgroundContext in
                    // Get a `User` instance from proper context!!!
                    let usr = backgroundContext.object(with: user.objectID) as! User
                    usr.avatar = randomUser.avatar

                    do {
                        try backgroundContext.save()

                        DispatchQueue.main.async {
                            completionHandler()
                        }
                    } catch {
                        os_log("%{public}@", error.localizedDescription)
                    }
                }
            })
    }


    private static let randomUserURL = URL(string: "https://random-data-api.com/api/users/random_user")!
    private static let avatarURLBase = URL(string: "https://source.unsplash.com/featured")!


    private func avatarPublisher(with user: RandomUser) -> AnyPublisher<RandomUser, Error> {
        let url = Self.avatarURLBase.appendingPathComponent("?\(user.address.country)")
        
        return theURLSession.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let response = response as? HTTPURLResponse else {
                    throw ServerSideError.nonHTTPResponse
                }

                guard (200...299).contains(response.statusCode) else {
                    throw ServerSideError.httpServerError(response.statusCode)
                }

                var usr = user
                usr.avatar = data

                return usr
            }
            .eraseToAnyPublisher()
    }


    private var randomUserPublisher: AnyPublisher<RandomUser, Error> {
        return theURLSession.dataTaskPublisher(for: Self.randomUserURL)
            .tryMap { data, response in
                guard let response = response as? HTTPURLResponse else {
                    throw ServerSideError.nonHTTPResponse
                }

                guard (200...299).contains(response.statusCode) else {
                    throw ServerSideError.httpServerError(response.statusCode)
                }

                return data
            }
            .decode(type: RandomUser.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }


    private let theURLSession: URLSession
    private var randomUserSubscriber: AnyCancellable?
    private var updateAvatarSubscriber: AnyCancellable?
}





private struct RandomUser: Decodable {
    init() {
        firstName = ""
        lastName = ""
        username = ""
        address = Address(country: "")
        phoneNumber = ""
        creditCard = CreditCard(number: "28")
        subscription = Subscription(paymentMethod: "")
    }

    let firstName: String
    let lastName: String
    let username: String
    var address: Address
    let phoneNumber: String
    let creditCard: CreditCard
    let subscription: Subscription

    var avatar: Data? = nil

    private enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case address
        case phoneNumber = "phone_number"
        case creditCard = "credit_card"
        case subscription
    }
}


private struct Address: Decodable {
    var country: String
}


struct CreditCard: Decodable {
    let number: String

    private enum CodingKeys: String, CodingKey {
        case number = "cc_number"
    }
}



private struct Subscription: Decodable {
    let paymentMethod: String

    private enum CodingKeys: String, CodingKey {
        case paymentMethod = "payment_method"
    }
}



private enum ServerSideError {
    case nonHTTPResponse
    case httpServerError(Int)
}




extension ServerSideError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .nonHTTPResponse:
            return NSLocalizedString("Server returned a non HTTP response", comment: "Not a HTTPURLResponse")
        case .httpServerError(let statusCode):
            return NSLocalizedString("Server returned \(statusCode)", comment: "A HTTPURLResponse status code not covered by HTTPStatusCode")
        }
    }
}
