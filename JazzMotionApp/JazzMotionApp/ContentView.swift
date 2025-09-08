import SwiftUI

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var musicEngine: MusicSelectionEngine
    
    @State private var showingSettings = false
    @State private var showingTrackList = false
    
    init() {
        let motionMgr = MotionManager()
        let audioMgr = AudioManager()
        let musicEng = MusicSelectionEngine(motionManager: motionMgr, audioManager: audioMgr)
        
        self._motionManager = StateObject(wrappedValue: motionMgr)
        self._audioManager = StateObject(wrappedValue: audioMgr)
        self._musicEngine = StateObject(wrappedValue: musicEng)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Градиентный фон, меняющийся в зависимости от интенсивности
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Заголовок
                        headerView
                        
                        // Карточка с текущим состоянием
                        motionStatusCard
                        
                        // Музыкальный плеер
                        musicPlayerCard
                        
                        // Карточка с информацией об аудиоустройстве
                        audioDeviceCard
                        
                        // Элементы управления
                        controlsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(motionManager: motionManager, 
                        audioManager: audioManager, 
                        musicEngine: musicEngine)
        }
        .sheet(isPresented: $showingTrackList) {
            TrackListView(audioManager: audioManager)
        }
        .onAppear {
            motionManager.startMotionUpdates()
        }
        .onDisappear {
            motionManager.stopMotionUpdates()
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 1.0), value: motionManager.motionIntensity)
    }
    
    private var gradientColors: [Color] {
        switch motionManager.motionIntensity {
        case .calm:
            return [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]
        case .moderate:
            return [Color.green.opacity(0.3), Color.blue.opacity(0.2)]
        case .active:
            return [Color.orange.opacity(0.3), Color.red.opacity(0.2)]
        case .energetic:
            return [Color.red.opacity(0.4), Color.pink.opacity(0.3)]
        }
    }
    
    private var headerView: some View {
        VStack {
            HStack {
                Text("🎷")
                    .font(.system(size: 40))
                
                VStack(alignment: .leading) {
                    Text("Jazz Motion")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Музыка под ваше движение")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var motionStatusCard: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Состояние движения")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Circle()
                    .fill(intensityColor)
                    .frame(width: 12, height: 12)
                    .scaleEffect(motionManager.isMotionActive ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), 
                              value: motionManager.isMotionActive)
            }
            
            // Индикатор интенсивности
            IntensityIndicatorView(intensity: motionManager.motionIntensity,
                                 accelerationMagnitude: motionManager.accelerationMagnitude,
                                 gyroscopeMagnitude: motionManager.gyroscopeMagnitude)
            
            // Числовые значения
            HStack(spacing: 30) {
                VStack {
                    Text("Ускорение")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", motionManager.accelerationMagnitude))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("Вращение")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", motionManager.gyroscopeMagnitude))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.9))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
    
    private var musicPlayerCard: some View {
        VStack(spacing: 15) {
            // Информация о треке
            if let track = audioManager.currentTrack {
                VStack(spacing: 8) {
                    Text(track.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(musicEngine.currentMusicStyle.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(intensityColor.opacity(0.2))
                            .cornerRadius(12)
                        
                        Text("\(track.bpm) BPM")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
            } else {
                Text("Выберите трек")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Прогресс трека
            if audioManager.duration > 0 {
                ProgressView(value: audioManager.currentTime, total: audioManager.duration)
                    .progressViewStyle(LinearProgressViewStyle(tint: intensityColor))
                
                HStack {
                    Text(formatTime(audioManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTime(audioManager.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Элементы управления плеером
            HStack(spacing: 40) {
                Button(action: { audioManager.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Button(action: togglePlayback) {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(intensityColor)
                }
                
                Button(action: { audioManager.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            
            // Регулятор громкости
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)
                
                Slider(value: Binding(
                    get: { audioManager.volume },
                    set: { audioManager.setVolume($0) }
                ), in: 0...1)
                .accentColor(intensityColor)
                
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.95))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
    
    private var audioDeviceCard: some View {
        HStack {
            Image(systemName: audioDeviceIcon)
                .font(.title2)
                .foregroundColor(audioDeviceColor)
            
            VStack(alignment: .leading) {
                Text("Аудиоустройство")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(audioManager.connectedAudioDevice)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            if audioManager.connectedAudioDevice.contains("AirPods") {
                Text("🎧")
                    .font(.title2)
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 3)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 15) {
            // Переключатель автоматического режима
            HStack {
                VStack(alignment: .leading) {
                    Text("Автоматический режим")
                        .font(.headline)
                    
                    Text("Музыка подбирается автоматически")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { musicEngine.isAutoModeEnabled },
                    set: { enabled in
                        if enabled {
                            musicEngine.enableAutoMode()
                        } else {
                            musicEngine.disableAutoMode()
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: intensityColor))
            }
            .padding(15)
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            
            // Кнопки действий
            HStack(spacing: 15) {
                Button(action: { showingTrackList = true }) {
                    Label("Треки", systemImage: "music.note.list")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(intensityColor.opacity(0.2))
                        .cornerRadius(12)
                }
                
                Button(action: { musicEngine.calibrateForUser() }) {
                    Label("Калибровка", systemImage: "tuningfork")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var intensityColor: Color {
        switch motionManager.motionIntensity {
        case .calm:
            return .blue
        case .moderate:
            return .green
        case .active:
            return .orange
        case .energetic:
            return .red
        }
    }
    
    private var audioDeviceIcon: String {
        if audioManager.connectedAudioDevice.contains("AirPods") {
            return "airpods"
        } else if audioManager.connectedAudioDevice.contains("Bluetooth") {
            return "headphones"
        } else if audioManager.connectedAudioDevice.contains("Speaker") {
            return "speaker.wave.2"
        } else {
            return "headphones"
        }
    }
    
    private var audioDeviceColor: Color {
        if audioManager.connectedAudioDevice.contains("AirPods") {
            return .white
        } else {
            return .primary
        }
    }
    
    private func togglePlayback() {
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.play()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Intensity Indicator View
struct IntensityIndicatorView: View {
    let intensity: MotionManager.MotionIntensity
    let accelerationMagnitude: Double
    let gyroscopeMagnitude: Double
    
    var body: some View {
        VStack(spacing: 10) {
            Text(intensity.description)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(intensityColor)
            
            // Визуальный индикатор интенсивности
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < intensityLevel ? intensityColor : Color.gray.opacity(0.3))
                        .frame(width: 50, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: intensityLevel)
                }
            }
        }
    }
    
    private var intensityColor: Color {
        switch intensity {
        case .calm:
            return .blue
        case .moderate:
            return .green
        case .active:
            return .orange
        case .energetic:
            return .red
        }
    }
    
    private var intensityLevel: Int {
        switch intensity {
        case .calm:
            return 1
        case .moderate:
            return 2
        case .active:
            return 3
        case .energetic:
            return 4
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}