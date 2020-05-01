//
//  ChannelSubscribingPage.swift
//  Puffery
//
//  Created by Valentin Knabel on 01.05.20.
//  Copyright © 2020 Valentin Knabel. All rights reserved.
//

import SwiftUI
import UserNotifications
import APIDefinition

struct ChannelSubscribingPage: View {
    @State var channelKey: String = ""
    private var api: API { Current.api }

    var isUUID: Bool {
        UUID(uuidString: channelKey) != nil
    }
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        Form {
            Section(footer: Text("Insert a notify key or a receive only key.")) {
                TextField("Channel Key", text: $channelKey, onCommit: createChannel)
            }
            Section {
                Button(action: createChannel) {
                    Text("Subscribe")
                }.disabled(!isUUID)
            }
        }.navigationBarTitle("Subscribe Channel", displayMode: NavigationBarItem.TitleDisplayMode.inline)
            .navigationBarItems(
                leading: cancelNavigationItem,
                trailing: createNavigationItem
            )
            .onAppear { Current.tracker.record("channels/subscribe") }
            .onAppear {
                if let subscription = UIPasteboard.general.strings?.compactMap(UUID.init(uuidString:)).first {
                    self.channelKey = subscription.uuidString
                }
            }
    }

    var createNavigationItem: some View {
        Button(action: createChannel) {
            Text("Subscribe").fontWeight(.bold)
        }
    }

    var cancelNavigationItem: some View {
        Button(action: dismiss) {
            Text("Cancel")
        }
    }

    func createChannel() {
        PushNotifications.register {
            self.api.subscribe(CreateSubscriptionRequest(receiveOrNotifyKey: self.channelKey))
                .task(self.receiveChannel(result:))
        }
    }

    func receiveChannel(result: Result<SubscribedChannelResponse, FetchingError>) {
        switch result {
        case .success:
            dismiss()
        case let .failure(error):
            print("Error", error)
        }
    }

    func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

#if DEBUG
    struct ChannelSubscribingPage_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                ChannelSubscribingPage()
            }
        }
    }
#endif