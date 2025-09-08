import Foundation
import Combine

class MusicSelectionEngine: ObservableObject {
    private let motionManager: MotionManager
    private let audioManager: AudioManager
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isAutoModeEnabled: Bool = true
    @Published var currentMusicStyle: MusicStyle = .smooth
    @Published var transitionInProgress: Bool = false
    @Published var lastIntensityChange: Date = Date()
    
    // Параметры для умного переключения музыки
    private let stabilityPeriod: TimeInterval = 3.0 // Время стабильности перед сменой трека
    private let transitionDelay: TimeInterval = 1.0 // Задержка перед сменой
    private var intensityStabilityTimer: Timer?
    private var pendingIntensity: MotionManager.MotionIntensity?
    
    enum MusicStyle: String, CaseIterable {
        case smooth = "Smooth Jazz"
        case bebop = "Bebop"
        case swing = "Swing"
        case fusion = "Fusion"
        
        var description: String {
            switch self {
            case .smooth:
                return "Плавный джаз для спокойных моментов"
            case .bebop:
                return "Быстрый бибоп для активного движения"
            case .swing:
                return "Свинг для ритмичных движений"
            case .fusion:
                return "Фьюжн для энергичной активности"
            }
        }
    }
    
    init(motionManager: MotionManager, audioManager: AudioManager) {
        self.motionManager = motionManager
        self.audioManager = audioManager
        
        setupMotionObservation()
    }
    
    private func setupMotionObservation() {
        // Подписываемся на изменения интенсивности движения
        motionManager.motionIntensityPublisher
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] intensity in
                self?.handleIntensityChange(intensity)
            }
            .store(in: &cancellables)
        
        // Наблюдаем за изменениями в состоянии движения
        motionManager.$motionIntensity
            .removeDuplicates()
            .sink { [weak self] intensity in
                self?.analyzeMotionPattern(intensity)
            }
            .store(in: &cancellables)
    }
    
    private func handleIntensityChange(_ newIntensity: MotionManager.MotionIntensity) {
        guard isAutoModeEnabled else { return }
        
        // Отменяем предыдущий таймер стабильности
        intensityStabilityTimer?.invalidate()
        
        // Если интенсивность изменилась, запускаем таймер стабильности
        pendingIntensity = newIntensity
        
        intensityStabilityTimer = Timer.scheduledTimer(withTimeInterval: stabilityPeriod, repeats: false) { [weak self] _ in
            self?.confirmIntensityChange()
        }
    }
    
    private func confirmIntensityChange() {
        guard let pendingIntensity = pendingIntensity,
              pendingIntensity == motionManager.motionIntensity else { return }
        
        // Проверяем, нужно ли менять музыку
        if shouldChangeMusic(for: pendingIntensity) {
            performMusicTransition(to: pendingIntensity)
        }
        
        self.pendingIntensity = nil
    }
    
    private func shouldChangeMusic(for intensity: MotionManager.MotionIntensity) -> Bool {
        // Не меняем музыку, если уже играет подходящий трек
        guard let currentTrack = audioManager.currentTrack else { return true }
        
        // Если интенсивность трека соответствует текущей, не меняем
        if currentTrack.intensity == intensity {
            return false
        }
        
        // Проверяем, прошло ли достаточно времени с последней смены
        let timeSinceLastChange = Date().timeIntervalSince(lastIntensityChange)
        return timeSinceLastChange > transitionDelay
    }
    
    private func performMusicTransition(to intensity: MotionManager.MotionIntensity) {
        transitionInProgress = true
        lastIntensityChange = Date()
        
        // Обновляем стиль музыки на основе интенсивности
        updateMusicStyle(for: intensity)
        
        // Выполняем плавный переход
        performSmoothTransition {
            self.audioManager.selectTrackForIntensity(intensity)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.transitionInProgress = false
            }
        }
    }
    
    private func updateMusicStyle(for intensity: MotionManager.MotionIntensity) {
        let newStyle: MusicStyle
        
        switch intensity {
        case .calm:
            newStyle = .smooth
        case .moderate:
            newStyle = .swing
        case .active:
            newStyle = .bebop
        case .energetic:
            newStyle = .fusion
        }
        
        if currentMusicStyle != newStyle {
            currentMusicStyle = newStyle
        }
    }
    
    private func performSmoothTransition(completion: @escaping () -> Void) {
        // Плавное уменьшение громкости
        let originalVolume = audioManager.volume
        
        fadeOut { [weak self] in
            completion()
            
            // Плавное увеличение громкости для нового трека
            self?.fadeIn(to: originalVolume)
        }
    }
    
    private func fadeOut(completion: @escaping () -> Void) {
        let fadeSteps = 10
        let fadeInterval = 0.05
        let volumeStep = audioManager.volume / Float(fadeSteps)
        
        var currentStep = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { timer in
            currentStep += 1
            let newVolume = self.audioManager.volume - volumeStep
            self.audioManager.setVolume(max(0, newVolume))
            
            if currentStep >= fadeSteps {
                timer.invalidate()
                completion()
            }
        }
    }
    
    private func fadeIn(to targetVolume: Float) {
        let fadeSteps = 10
        let fadeInterval = 0.05
        let volumeStep = targetVolume / Float(fadeSteps)
        
        var currentStep = 0
        audioManager.setVolume(0)
        
        let timer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { timer in
            currentStep += 1
            let newVolume = volumeStep * Float(currentStep)
            self.audioManager.setVolume(min(targetVolume, newVolume))
            
            if currentStep >= fadeSteps {
                timer.invalidate()
            }
        }
    }
    
    private func analyzeMotionPattern(_ intensity: MotionManager.MotionIntensity) {
        // Анализируем паттерн движения для более точного подбора музыки
        let acceleration = motionManager.accelerationMagnitude
        let gyroscope = motionManager.gyroscopeMagnitude
        
        // Определяем тип движения
        let movementType = classifyMovementType(acceleration: acceleration, gyroscope: gyroscope)
        
        // Можно использовать эту информацию для более тонкой настройки музыки
        adjustMusicForMovementType(movementType, intensity: intensity)
    }
    
    private func classifyMovementType(acceleration: Double, gyroscope: Double) -> MovementType {
        let accelToGyroRatio = acceleration / max(gyroscope, 0.001)
        
        switch accelToGyroRatio {
        case 0..<0.5:
            return .rotation // Больше поворотов
        case 0.5..<2.0:
            return .mixed    // Смешанное движение
        default:
            return .linear   // Больше линейного движения
        }
    }
    
    private func adjustMusicForMovementType(_ movementType: MovementType, intensity: MotionManager.MotionIntensity) {
        // Здесь можно реализовать дополнительную логику
        // для более точного подбора музыки на основе типа движения
        
        // Например, для вращательных движений можно выбирать треки с более сложным ритмом
        // Для линейных движений - треки с четким битом
    }
    
    // MARK: - Public Methods
    
    func enableAutoMode() {
        isAutoModeEnabled = true
        
        // Немедленно подбираем трек для текущей интенсивности
        if motionManager.isMotionActive {
            handleIntensityChange(motionManager.motionIntensity)
        }
    }
    
    func disableAutoMode() {
        isAutoModeEnabled = false
        intensityStabilityTimer?.invalidate()
        pendingIntensity = nil
    }
    
    func manualTrackSelection(for intensity: MotionManager.MotionIntensity) {
        // Позволяет пользователю вручную выбрать трек для определенной интенсивности
        disableAutoMode()
        audioManager.selectTrackForIntensity(intensity)
    }
    
    func calibrateForUser() {
        // Калибровка системы под конкретного пользователя
        motionManager.calibrateThresholds()
        
        // Можно добавить персонализированные настройки музыки
    }
    
    func getRecommendationsForCurrentIntensity() -> [String] {
        let intensity = motionManager.motionIntensity
        
        switch intensity {
        case .calm:
            return [
                "Медленные баллады и блюз",
                "Акустический джаз",
                "Мелодичные композиции"
            ]
        case .moderate:
            return [
                "Классический джаз",
                "Свинг среднего темпа",
                "Латинский джаз"
            ]
        case .active:
            return [
                "Бибоп и хард-боп",
                "Фанк-джаз",
                "Энергичные импровизации"
            ]
        case .energetic:
            return [
                "Фьюжн и джаз-рок",
                "Быстрый бибоп",
                "Экспериментальный джаз"
            ]
        }
    }
    
    deinit {
        intensityStabilityTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum MovementType {
    case linear    // Линейное движение (ходьба, бег)
    case rotation  // Вращательное движение (повороты)
    case mixed     // Смешанное движение
}