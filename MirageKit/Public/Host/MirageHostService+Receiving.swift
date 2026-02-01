//
//  MirageHostService+Receiving.swift
//  MirageKit
//
//  Created by Ethan Lipnik on 1/24/26.
//
//  Control message receiving loop.
//

import Foundation
import Network

#if os(macOS)
@MainActor
extension MirageHostService {
    /// Continuously receive and handle control messages from a client.
    func startReceivingFromClient(connection: NWConnection, client: MirageConnectedClient) {
        let connectionID = ObjectIdentifier(connection)

        // Use a class-based wrapper to allow recursive calls
        final class Receiver {
            weak var service: MirageHostService?
            let connection: NWConnection
            let client: MirageConnectedClient
            let connectionID: ObjectIdentifier
            var receiveBuffer = Data()
            let bufferLock = NSLock()
            
            init(service: MirageHostService, connection: NWConnection, client: MirageConnectedClient, connectionID: ObjectIdentifier) {
                self.service = service
                self.connection = connection
                self.client = client
                self.connectionID = connectionID
            }
            
            func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                    guard let self else { return }
                    
                    self.bufferLock.lock()
                    if let data, !data.isEmpty { self.receiveBuffer.append(data) }
                    
                    var messages: [(message: ControlMessage, isInput: Bool)] = []
                    while let (message, consumed) = ControlMessage.deserialize(from: self.receiveBuffer) {
                        self.receiveBuffer.removeFirst(consumed)
                        messages.append((message, message.type == .inputEvent))
                    }
                    self.bufferLock.unlock()
                    
                    for (message, isInput) in messages where isInput {
                        self.service?.inputQueue.async { [weak self] in
                            guard let service = self?.service else { return }
                            Task { @MainActor in
                                guard let receiver = self else { return }
                                service.handleInputEventFast(message, from: receiver.client)
                            }
                        }
                    }
                    
                    let nonInputMessages = messages.filter { !$0.isInput }.map(\.message)
                    if !nonInputMessages.isEmpty || error != nil || isComplete {
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            guard let service = self.service else { return }
                            
                            if !nonInputMessages.isEmpty { service.clientFirstErrorTime.removeValue(forKey: self.connectionID) }
                            
                            for message in nonInputMessages {
                                await service.handleClientMessage(message, from: self.client, connection: self.connection)
                            }
                            
                            if let error {
                                let isFatalError = service.isFatalConnectionError(error)
                                
                                if isFatalError {
                                    MirageLogger.error(
                                        .host,
                                        "Client \(self.client.name) fatal connection error - disconnecting: \(error)"
                                    )
                                    service.clientFirstErrorTime.removeValue(forKey: self.connectionID)
                                    await service.disconnectClient(self.client)
                                    return
                                }
                                
                                let now = CFAbsoluteTimeGetCurrent()
                                if let firstErrorTime = service.clientFirstErrorTime[self.connectionID] {
                                    let errorDuration = now - firstErrorTime
                                    if errorDuration >= service.clientErrorTimeoutSeconds {
                                        MirageLogger.error(
                                            .host,
                                            "Client \(self.client.name) errors persisted for \(Int(errorDuration))s - disconnecting"
                                        )
                                        service.clientFirstErrorTime.removeValue(forKey: self.connectionID)
                                        await service.disconnectClient(self.client)
                                        return
                                    }
                                    MirageLogger
                                        .host(
                                            "Client \(self.client.name) error (persisting for \(Int(errorDuration))s): \(error)"
                                        )
                                } else {
                                    service.clientFirstErrorTime[self.connectionID] = now
                                    MirageLogger
                                        .host(
                                            "Client \(self.client.name) transient error, will disconnect after \(Int(service.clientErrorTimeoutSeconds))s if not recovered: \(error)"
                                        )
                                }
                                self.receiveNext()
                                return
                            }
                            
                            if isComplete {
                                MirageLogger.host("Client disconnected")
                                service.clientFirstErrorTime.removeValue(forKey: self.connectionID)
                                await service.disconnectClient(self.client)
                                return
                            }
                            
                            self.receiveNext()
                        }
                    } else {
                        Task { @MainActor [weak self] in
                            self?.receiveNext()
                        }
                    }
                }
            }
        }
        
        let receiver = Receiver(service: self, connection: connection, client: client, connectionID: connectionID)
        receiver.receiveNext()
    }
}
#endif
