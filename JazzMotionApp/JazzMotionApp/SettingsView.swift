import SwiftUI

struct SettingsView: View {
    @ObservedObject var motionManager: MotionManager
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var musicEngine: MusicSelectionEngine
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var sensitivityLevel: Double = 0.5
    @State private var transitionSpeed: Double = 3.0
    @State private var showingCalibration = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Датчики движения") {
                    HStack {
                        Text("Чувствительность")
                        Spacer()
                        Text(String(format: "%.0f%%", sensitivityLevel * 100))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $sensitivityLevel, in: 0...1)
                        .accentColor(.blue)
                    
                    Text("Настройте чувствительность датчиков под ваш стиль движения")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Переключение музыки") {
                    HStack {
                        Text("Скорость адаптации")
                        Spacer()
                        Text(String(format: "%.1f сек", transitionSpeed))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $transitionSpeed, in: 1...10)
                        .accentColor(.green)
                    
                    Text("Время, через которое музыка адаптируется к новой интенсивности движения")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Аудио") {
                    HStack {
                        Image(systemName: audioDeviceIcon)
                            .foregroundColor(audioDeviceColor)
                        
                        VStack(alignment: .leading) {
                            Text("Подключенное устройство")
                                .font(.subheadline)
                            Text(audioManager.connectedAudioDevice)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if audioManager.connectedAudioDevice.contains("AirPods") {
                            Text("✓")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    
                    Toggle("Фоновое воспроизведение", isOn: .constant(true))
                        .disabled(true)
                    
                    Text("Музыка продолжает играть даже когда приложение свернуто")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Калибровка") {
                    Button("Запустить калибровку") {
                        showingCalibration = true
                    }
                    .foregroundColor(.blue)
                    
                    Text("Персонализируйте приложение под ваш стиль движения")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Музыкальные стили") {
                    ForEach(MusicSelectionEngine.MusicStyle.allCases, id: \.self) { style in
                        HStack {
                            Text(style.rawValue)
                            Spacer()
                            if style == musicEngine.currentMusicStyle {
                                Text("Текущий")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section("Рекомендации") {
                    DisclosureGroup("Для текущей интенсивности") {
                        ForEach(musicEngine.getRecommendationsForCurrentIntensity(), id: \.self) { recommendation in
                            Text("• \(recommendation)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Информация") {
                    HStack {
                        Text("Версия приложения")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Статус датчиков")
                        Spacer()
                        Circle()
                            .fill(motionManager.isMotionActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(motionManager.isMotionActive ? "Активны" : "Неактивны")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(motionManager: motionManager)
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
            return .blue
        } else {
            return .primary
        }
    }
}

struct CalibrationView: View {
    @ObservedObject var motionManager: MotionManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var calibrationStep = 0
    @State private var isCalibrating = false
    @State private var calibrationProgress: Double = 0
    
    private let calibrationSteps = [
        "Встаньте спокойно и не двигайтесь",
        "Медленно походите по комнате",
        "Двигайтесь в умеренном темпе",
        "Активно двигайтесь или танцуйте"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Калибровка датчиков")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Поможет приложению лучше понимать ваш стиль движения")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if isCalibrating {
                    VStack(spacing: 20) {
                        Text("Шаг \(calibrationStep + 1) из \(calibrationSteps.count)")
                            .font(.headline)
                        
                        Text(calibrationSteps[calibrationStep])
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        ProgressView(value: calibrationProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: 200)
                        
                        Text("Осталось \(Int((1 - calibrationProgress) * 10)) секунд")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Готовы начать?")
                            .font(.title2)
                        
                        Button("Начать калибровку") {
                            startCalibration()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("Отмена") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func startCalibration() {
        isCalibrating = true
        calibrationStep = 0
        calibrationProgress = 0
        
        performCalibrationStep()
    }
    
    private func performCalibrationStep() {
        let stepDuration = 10.0
        let updateInterval = 0.1
        let totalUpdates = Int(stepDuration / updateInterval)
        var currentUpdate = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            currentUpdate += 1
            calibrationProgress = Double(currentUpdate) / Double(totalUpdates)
            
            if currentUpdate >= totalUpdates {
                timer.invalidate()
                
                if calibrationStep < calibrationSteps.count - 1 {
                    calibrationStep += 1
                    calibrationProgress = 0
                    performCalibrationStep()
                } else {
                    completeCalibration()
                }
            }
        }
    }
    
    private func completeCalibration() {
        // Выполняем калибровку в менеджере движения
        motionManager.calibrateThresholds()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct TrackListView: View {
    @ObservedObject var audioManager: AudioManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedIntensity: MotionManager.MotionIntensity = .calm
    
    // Демонстрационные треки (в реальном приложении будут загружаться из файлов)
    private let tracksByIntensity: [MotionManager.MotionIntensity: [JazzTrack]] = [
        .calm: [
            JazzTrack(name: "Blue Moon", artist: "Bill Evans", filename: "blue_moon", bpm: 60, intensity: .calm),
            JazzTrack(name: "Autumn Leaves", artist: "Miles Davis", filename: "autumn_leaves", bpm: 65, intensity: .calm),
            JazzTrack(name: "Body and Soul", artist: "Coleman Hawkins", filename: "body_and_soul", bpm: 58, intensity: .calm),
            JazzTrack(name: "Misty", artist: "Erroll Garner", filename: "misty", bpm: 62, intensity: .calm)
        ],
        .moderate: [
            JazzTrack(name: "All of Me", artist: "Django Reinhardt", filename: "all_of_me", bpm: 100, intensity: .moderate),
            JazzTrack(name: "Summertime", artist: "Ella Fitzgerald", filename: "summertime", bpm: 95, intensity: .moderate),
            JazzTrack(name: "Fly Me to the Moon", artist: "Frank Sinatra", filename: "fly_me_to_moon", bpm: 105, intensity: .moderate)
        ],
        .active: [
            JazzTrack(name: "Take Five", artist: "Dave Brubeck", filename: "take_five", bpm: 140, intensity: .active),
            JazzTrack(name: "So What", artist: "Miles Davis", filename: "so_what", bpm: 135, intensity: .active),
            JazzTrack(name: "A Love Supreme", artist: "John Coltrane", filename: "love_supreme", bpm: 145, intensity: .active)
        ],
        .energetic: [
            JazzTrack(name: "Giant Steps", artist: "John Coltrane", filename: "giant_steps", bpm: 180, intensity: .energetic),
            JazzTrack(name: "Cherokee", artist: "Charlie Parker", filename: "cherokee", bpm: 200, intensity: .energetic),
            JazzTrack(name: "Donna Lee", artist: "Charlie Parker", filename: "donna_lee", bpm: 190, intensity: .energetic)
        ]
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Селектор интенсивности
                Picker("Интенсивность", selection: $selectedIntensity) {
                    ForEach(MotionManager.MotionIntensity.allCases, id: \.self) { intensity in
                        Text(intensity.description).tag(intensity)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Список треков
                List {
                    if let tracks = tracksByIntensity[selectedIntensity] {
                        ForEach(tracks) { track in
                            TrackRowView(track: track, 
                                       isCurrentTrack: audioManager.currentTrack?.id == track.id,
                                       isPlaying: audioManager.isPlaying) {
                                selectTrack(track)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Джазовые треки")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func selectTrack(_ track: JazzTrack) {
        // Здесь будет логика выбора и воспроизведения трека
        audioManager.selectTrackForIntensity(track.intensity)
        if !audioManager.isPlaying {
            audioManager.play()
        }
    }
}

struct TrackRowView: View {
    let track: JazzTrack
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.headline)
                    .foregroundColor(isCurrentTrack ? .blue : .primary)
                
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(track.bpm) BPM")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    
                    Text(track.intensity.description)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(intensityColor.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
            
            if isCurrentTrack {
                Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var intensityColor: Color {
        switch track.intensity {
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
}