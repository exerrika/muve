import Foundation
import AVFoundation
import MediaPlayer
import Combine

class AudioManager: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession
    
    @Published var isPlaying: Bool = false
    @Published var currentTrack: JazzTrack?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.7
    @Published var connectedAudioDevice: String = "iPhone"
    
    // Джазовые треки для разных уровней интенсивности
    private let jazzTracks: [MotionManager.MotionIntensity: [JazzTrack]] = [
        .calm: [
            JazzTrack(name: "Blue Moon", artist: "Bill Evans", filename: "blue_moon", bpm: 60, intensity: .calm),
            JazzTrack(name: "Autumn Leaves", artist: "Miles Davis", filename: "autumn_leaves", bpm: 65, intensity: .calm),
            JazzTrack(name: "Body and Soul", artist: "Coleman Hawkins", filename: "body_and_soul", bpm: 58, intensity: .calm),
            JazzTrack(name: "Misty", artist: "Erroll Garner", filename: "misty", bpm: 62, intensity: .calm)
        ],
        .moderate: [
            JazzTrack(name: "All of Me", artist: "Django Reinhardt", filename: "all_of_me", bpm: 100, intensity: .moderate),
            JazzTrack(name: "Summertime", artist: "Ella Fitzgerald", filename: "summertime", bpm: 95, intensity: .moderate),
            JazzTrack(name: "Fly Me to the Moon", artist: "Frank Sinatra", filename: "fly_me_to_moon", bpm: 105, intensity: .moderate),
            JazzTrack(name: "The Way You Look Tonight", artist: "Tony Bennett", filename: "way_you_look", bpm: 98, intensity: .moderate)
        ],
        .active: [
            JazzTrack(name: "Take Five", artist: "Dave Brubeck", filename: "take_five", bpm: 140, intensity: .active),
            JazzTrack(name: "So What", artist: "Miles Davis", filename: "so_what", bpm: 135, intensity: .active),
            JazzTrack(name: "A Love Supreme", artist: "John Coltrane", filename: "love_supreme", bpm: 145, intensity: .active),
            JazzTrack(name: "Cantaloupe Island", artist: "Herbie Hancock", filename: "cantaloupe_island", bpm: 138, intensity: .active)
        ],
        .energetic: [
            JazzTrack(name: "Giant Steps", artist: "John Coltrane", filename: "giant_steps", bpm: 180, intensity: .energetic),
            JazzTrack(name: "Cherokee", artist: "Charlie Parker", filename: "cherokee", bpm: 200, intensity: .energetic),
            JazzTrack(name: "Donna Lee", artist: "Charlie Parker", filename: "donna_lee", bpm: 190, intensity: .energetic),
            JazzTrack(name: "Salt Peanuts", artist: "Dizzy Gillespie", filename: "salt_peanuts", bpm: 195, intensity: .energetic)
        ]
    ]
    
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupAudioSession()
        setupRemoteControls()
        observeAudioRouteChanges()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, 
                                       mode: .default, 
                                       options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try audioSession.setActive(true)
            
            // Обновляем информацию о подключенном устройстве
            updateConnectedAudioDevice()
            
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
    }
    
    private func observeAudioRouteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func audioRouteChanged(notification: Notification) {
        updateConnectedAudioDevice()
    }
    
    private func updateConnectedAudioDevice() {
        let outputs = audioSession.currentRoute.outputs
        
        if let output = outputs.first {
            DispatchQueue.main.async {
                switch output.portType {
                case .bluetoothA2DP:
                    self.connectedAudioDevice = output.portName // Название AirPods/наушников
                case .bluetoothHFP:
                    self.connectedAudioDevice = "Bluetooth Headset"
                case .builtInSpeaker:
                    self.connectedAudioDevice = "iPhone Speaker"
                case .headphones:
                    self.connectedAudioDevice = "Wired Headphones"
                case .airPlay:
                    self.connectedAudioDevice = "AirPlay"
                default:
                    self.connectedAudioDevice = output.portName
                }
            }
        }
    }
    
    func selectTrackForIntensity(_ intensity: MotionManager.MotionIntensity) {
        guard let tracks = jazzTracks[intensity], !tracks.isEmpty else { return }
        
        // Выбираем случайный трек для данной интенсивности
        let randomTrack = tracks.randomElement()!
        
        // Если это тот же трек, что играет сейчас, не меняем
        if currentTrack?.filename == randomTrack.filename && isPlaying {
            return
        }
        
        loadTrack(randomTrack)
    }
    
    private func loadTrack(_ track: JazzTrack) {
        // В реальном приложении здесь будет загрузка аудиофайла
        // Пока что создаем заглушку с синтезированным звуком
        guard let url = createDemoAudioFile(for: track) else {
            print("Failed to create audio file for track: \(track.name)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = volume
            
            DispatchQueue.main.async {
                self.currentTrack = track
                self.duration = self.audioPlayer?.duration ?? 0
                self.updateNowPlayingInfo()
            }
            
            if isPlaying {
                play()
            }
            
        } catch {
            print("Failed to load track: \(error)")
        }
    }
    
    private func createDemoAudioFile(for track: JazzTrack) -> URL? {
        // Создаем демо-файл с синтезированным звуком
        // В реальном приложении здесь будут настоящие аудиофайлы
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("\(track.filename).wav")
        
        // Если файл уже существует, возвращаем его
        if FileManager.default.fileExists(atPath: audioURL.path) {
            return audioURL
        }
        
        // Создаем простой синтезированный звук для демонстрации
        return generateDemoAudio(for: track, at: audioURL)
    }
    
    private func generateDemoAudio(for track: JazzTrack, at url: URL) -> URL? {
        // Простая генерация звука для демонстрации
        // В реальном приложении здесь будут настоящие джазовые композиции
        
        let sampleRate: Double = 44100
        let duration: Double = 60 // 1 минута для демо
        let frequency: Double = track.getBaseFrequency()
        
        var audioData: [Float] = []
        
        for i in 0..<Int(sampleRate * duration) {
            let time = Double(i) / sampleRate
            let sample = Float(sin(2.0 * Double.pi * frequency * time) * 0.3)
            audioData.append(sample)
        }
        
        // Сохраняем в формате WAV (упрощенная версия)
        // В реальном приложении используйте AVAudioEngine или готовые аудиофайлы
        
        return url // Возвращаем URL для демонстрации
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        do {
            try audioSession.setActive(true)
            player.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
            }
            
            startTimeUpdates()
            
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        
        stopTimeUpdates()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
        }
        
        stopTimeUpdates()
    }
    
    func nextTrack() {
        guard let currentTrack = currentTrack,
              let tracks = jazzTracks[currentTrack.intensity],
              let currentIndex = tracks.firstIndex(where: { $0.filename == currentTrack.filename }) else { return }
        
        let nextIndex = (currentIndex + 1) % tracks.count
        loadTrack(tracks[nextIndex])
    }
    
    func previousTrack() {
        guard let currentTrack = currentTrack,
              let tracks = jazzTracks[currentTrack.intensity],
              let currentIndex = tracks.firstIndex(where: { $0.filename == currentTrack.filename }) else { return }
        
        let prevIndex = currentIndex > 0 ? currentIndex - 1 : tracks.count - 1
        loadTrack(tracks[prevIndex])
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioPlayer?.volume = volume
    }
    
    private var timeUpdateTimer: Timer?
    
    private func startTimeUpdates() {
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            
            DispatchQueue.main.async {
                self.currentTime = player.currentTime
            }
        }
    }
    
    private func stopTimeUpdates() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: track.name,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        
        // Добавляем обложку альбома (если есть)
        if let image = UIImage(systemName: "music.note") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopTimeUpdates()
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            nextTrack()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
    }
}

// MARK: - JazzTrack Model
struct JazzTrack: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let artist: String
    let filename: String
    let bpm: Int
    let intensity: MotionManager.MotionIntensity
    
    func getBaseFrequency() -> Double {
        // Возвращает базовую частоту для синтеза звука в зависимости от интенсивности
        switch intensity {
        case .calm:
            return 220.0 // A3
        case .moderate:
            return 330.0 // E4
        case .active:
            return 440.0 // A4
        case .energetic:
            return 660.0 // E5
        }
    }
}