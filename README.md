# MirageShare

A macOS screen sharing application that allows two Macs to share screens bidirectionally. Built on top of the MirageKit streaming framework.

## Features

- **Bidirectional Screen Sharing** - Any Mac can be both a host (sharer) and client (viewer)
- **Window Streaming** - Stream individual windows or full desktop
- **Bonjour Discovery** - Automatically find other Macs on the network
- **Peer-to-Peer (AWDL)** - Direct connections without requiring same WiFi
- **Full Input Support** - Mouse, keyboard, scroll forwarding to remote Mac
- **Quality Presets** - Ultra/High/Medium/Low quality settings
- **Menu Bar Integration** - Quick access from system tray
- **SwiftUI Interface** - Modern native macOS UI

## Architecture

### Host Mode (Share Your Screen)
```
┌─────────────────────────────────────────────────────────────┐
│  MirageShare Host                                           │
│  ┌─────────────────┐     ┌──────────────────────────────┐  │
│  │ MirageHostService│────▶│ Bonjour Advertisement        │  │
│  └─────────────────┘     └──────────────────────────────┘  │
│           │                                               │
│           ▼                                               │
│  ┌─────────────────┐     ┌──────────────────────────────┐  │
│  │ WindowCapture   │────▶│ HEVC Encoder (VideoToolbox)  │  │
│  │ (ScreenCapture) │     └──────────────────────────────┘  │
│  └─────────────────┘                    │                 │
│                                         ▼                 │
│  ┌─────────────────┐     ┌──────────────────────────────┐  │
│  │ InputController │◀────│ TCP Control + UDP Video      │  │
│  │ (Accessibility) │     └──────────────────────────────┘  │
│  └─────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
```

### Client Mode (View Remote Screen)
```
┌─────────────────────────────────────────────────────────────┐
│  MirageShare Client                                         │
│  ┌─────────────────┐     ┌──────────────────────────────┐  │
│  │ MirageHostBrowser│────▶│ Bonjour Discovery            │  │
│  └─────────────────┘     └──────────────────────────────┘  │
│           │                                               │
│           ▼                                               │
│  ┌─────────────────┐     ┌──────────────────────────────┐  │
│  │ MirageClientService    │ TCP Connect + Request Windows│  │
│  └─────────────────┘     └──────────────────────────────┘  │
│           │                                               │
│           ▼                                               │
│  ┌─────────────────┐     ┌──────────────────────────────┐  │
│  │ HEVCDecoder     │◀────│ UDP Video Receive            │  │
│  │ (VideoToolbox)  │     └──────────────────────────────┘  │
│  └─────────────────┘                    │                 │
│                                         ▼                 │
│  ┌─────────────────┐     ┌──────────────────────────────┐  │
│  │ MirageMetalView │────▶│ Metal Rendering + Input Send │  │
│  └─────────────────┘     └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
MirageShare/
├── Package.swift                    # Swift Package manifest
└── Sources/MirageShare/
    ├── MirageShareApp.swift         # App entry point (@main)
    ├── AppDelegate.swift            # Menu bar integration
    ├── MirageShareState.swift       # Central app state (@Observable)
    ├── Host/
    │   └── HostManager.swift        # Screen sharing host logic
    ├── Client/
    │   ├── ClientManager.swift      # Remote connection client
    │   └── HostBrowser.swift        # Bonjour discovery
    └── Views/
        ├── ContentView.swift        # Main tab view (Host/Client)
        ├── HostView.swift           # Share screen UI
        ├── ClientView.swift         # Connect to remote Mac UI
        ├── StreamWindowView.swift   # View remote streams
        └── SettingsView.swift       # App preferences
```

## Key Components

### HostManager
Manages the `MirageHostService` for sharing this Mac's screen:
- Start/stop advertising via Bonjour
- Accept client connections
- Handle stream requests
- Forward input events to local system

### ClientManager
Manages the `MirageClientService` for viewing remote screens:
- Discover hosts on the network
- Connect to remote Macs
- Start window/desktop streams
- Send input events to host

### MirageStreamContentView
MirageKit's view for rendering remote streams:
- Metal-backed rendering for performance
- Input capture and forwarding
- Focus management
- Resize handling

## Usage Flow

### Sharing Your Screen
1. Open MirageShare → "Share Screen" tab
2. Click "Start Sharing"
3. Your Mac appears as "HostName" on other Macs
4. Connected clients can view and control your screen

### Connecting to Another Mac
1. Open MirageShare → "Connect" tab
2. Select a Mac from the discovered list
3. Choose a window to stream or request desktop
4. Control the remote Mac with mouse and keyboard

## Network Protocol

- **Discovery**: Bonjour `_mirage._tcp`
- **Control**: TCP (port 9847) - JSON messages
- **Video**: UDP (port 9848) - HEVC encoded frames
- **Encryption**: TLS on TCP, optional on UDP

## Requirements

- macOS 14+ (Sonoma)
- Swift 6.0+
- Screen Recording permission (host mode)
- Accessibility permission (for input forwarding)

## Building

```bash
cd MirageShare
swift build
```

## Performance Optimizations

- Hardware HEVC encoding/decoding via VideoToolbox
- Metal rendering with zero-copy texture cache
- Limited in-flight frames (1-2 depending on refresh rate)
- Adaptive stream scaling for FPS recovery
- Queue-based backpressure for latency control
- 60-120 FPS support based on display capability

## License

Follows the same license as MirageKit (PolyForm Shield 1.0.0)
