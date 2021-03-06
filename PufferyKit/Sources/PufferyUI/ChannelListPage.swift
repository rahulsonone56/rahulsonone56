//
//  ChannelListPage.swift
//  Puffery
//
//  Created by Valentin Knabel on 18.04.20.
//  Copyright © 2020 Valentin Knabel. All rights reserved.
//

import Combine
import DesignSystem
import SwiftUI
import PlatformSupport

enum ChannelSelection: Hashable {
    case all
    case channel(Channel)
}

struct ChannelListPage: View {
    private var api: API { Current.api }

    @State var presentsSettings = false
    @State var presentsChannelCreation = false
    @State var presentsChannelSubscription = false
    @State var shouldReload = PassthroughSubject<Void, FetchingError>()
    @State var selection: ChannelSelection? = UIDevice.current.model == "iPad"
        ? .all
        : nil

    var isIpad: Bool { UIDevice.current.model == "iPad" }

    var body: some View {
        ZStack {
            List {
                Section {
                    NavigationLink(destination: ChannelDetailsPage(), tag: .all, selection: $selection) {
                        Text("ChannelList.All")
                            .sheet(isPresented: $presentsChannelCreation, onDismiss: shouldReload.send) {
                                NavigationView {
                                    ChannelCreationPage()
                                }.navigationViewStyle(StackNavigationViewStyle())
                            }
                    }
                }

                Section(header: createChannelHeader()) {
                    Fetching(loadOwnChannelsPublisher, empty: self.noChannelsFound()) { channels in
                        ForEach(channels) { channel in
                            NavigationLink(destination: ChannelDetailsPage(channel: channel), tag: .channel(channel), selection: self.$selection) {
                                Text(channel.title)
                            }
                        }
                    }
                }

                Section(header: subscribeChannelHeader()) {
                    Fetching(loadSharedChannelsPublisher, empty: self.noChannelsFound()) { channels in
                        ForEach(channels) { channel in
                            NavigationLink(destination: ChannelDetailsPage(channel: channel), tag: .channel(channel), selection: self.$selection) {
                                Text(channel.title)
                            }
                        }
                    }
                }
            }.roundedListStyle(sidebar: false)
        }
        .sheet(isPresented: $presentsSettings) {
            NavigationView {
                AppSettingsPage()
            }.navigationViewStyle(StackNavigationViewStyle())
        }
        .sheet(isPresented: $presentsChannelSubscription, onDismiss: shouldReload.send) {
            NavigationView {
                ChannelSubscribingPage()
            }.navigationViewStyle(StackNavigationViewStyle())
        }
        .navigationBarTitle("ChannelList.Title")
        .navigationBarItems(trailing: settingsNavigationBarItem)
        .record("app")
    }

    func createChannelHeader() -> some View {
        HStack {
            Text("ChannelList.OwnChannels.SectionTitle")
            Spacer()

            Button(action: { DispatchQueue.main.async {
                self.presentsChannelCreation.toggle()
            } }) {
                HStack {
                    #if !targetEnvironment(macCatalyst)
                    Text("ChannelList.OwnChannels.New")
                    #endif
                    Image(systemName: "plus.circle").font(.body)
                }.foregroundColor(.accentColor)
            }
        }
    }

    func subscribeChannelHeader() -> some View {
        channelsHeader("ChannelList.SubscribeChannels.SectionTitle", actionText: "ChannelList.SubscribeChannels.New", action: { self.presentsChannelSubscription.toggle() })
    }

    func channelsHeader(_ title: LocalizedStringKey, actionText: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()

            Button(action: action) {
                HStack {
                    #if !targetEnvironment(macCatalyst)
                    Text(actionText)
                    #endif
                    Image(systemName: "plus.circle").font(.body)
                }.foregroundColor(.accentColor)
            }
        }
    }

    func noChannelsFound(_ emptyTitle: LocalizedStringKey = "ChannelList.NoChannels") -> some View {
        HStack {
            Spacer()
            Text(emptyTitle).opacity(0.5)
            Spacer()
        }
    }

    var settingsNavigationBarItem: some View {
        Button(action: { self.presentsSettings.toggle() }) {
            Image(systemName: "person.crop.circle")
        }
    }

    init() {
        let didUnsubscribedFromChannel = NotificationCenter.default.publisher(for: .didUnsubscribeFromChannel)
            .transformError(to: FetchingError.self)
            .transform(to: ())
        let didSubscribeToChannel = NotificationCenter.default.publisher(for: .didSubscribeToChannel)
            .transformError(to: FetchingError.self)
            .transform(to: ())
        let didChangeChannel = NotificationCenter.default.publisher(for: .didChangeChannel)
            .transformError(to: FetchingError.self)
            .transform(to: ())

        loadOwnChannelsPublisher = shouldReload.merge(with: didUnsubscribedFromChannel)
            .merge(with: didSubscribeToChannel)
            .merge(with: didChangeChannel)
            .prepend(())
            .flatMap(api.ownChannels().publisher)
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { channels in
                if channels.contains(where: { !$0.isSilent }) {
                    PushNotifications.register()
                }
            })
            .eraseToAnyPublisher()

        loadSharedChannelsPublisher = shouldReload.merge(with: didUnsubscribedFromChannel)
            .merge(with: didSubscribeToChannel)
            .merge(with: didChangeChannel)
            .prepend(())
            .flatMap(api.sharedChannels().publisher)
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { channels in
                if channels.contains(where: { !$0.isSilent }) {
                    PushNotifications.register()
                }
            })
            .eraseToAnyPublisher()
    }

    var loadOwnChannelsPublisher: AnyPublisher<[Channel], FetchingError>!
    var loadSharedChannelsPublisher: AnyPublisher<[Channel], FetchingError>!
}

#if DEBUG
    struct ChannelListPage_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                ChannelListPage()
            }
        }
    }
#endif
