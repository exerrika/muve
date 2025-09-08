import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let operationQueue = OperationQueue()
    
    @Published var motionIntensity: MotionIntensity = .calm
    @Published var accelerationMagnitude: Double = 0.0
    @Published var gyroscopeMagnitude: Double = 0.0
    @Published var isMotionActive: Bool = false
    
    private var motionIntensitySubject = PassthroughSubject<MotionIntensity, Never>()
    var motionIntensityPublisher: AnyPublisher<MotionIntensity, Never> {
        motionIntensitySubject.eraseToAnyPublisher()
    }
    
    // Параметры для анализа движения
    private let updateInterval: TimeInterval = 0.1
    private let smoothingFactor: Double = 0.3
    private var smoothedAcceleration: Double = 0.0
    private var smoothedGyroscope: Double = 0.0
    
    // Пороговые значения для определения интенсивности
    private let calmThreshold: Double = 0.2
    private let moderateThreshold: Double = 0.8
    private let activeThreshold: Double = 1.5
    
    enum MotionIntensity: String, CaseIterable {
        case calm = "Calm"
        case moderate = "Moderate"
        case active = "Active"
        case energetic = "Energetic"
        
        var description: String {
            switch self {
            case .calm:
                return "Спокойное состояние"
            case .moderate:
                return "Умеренное движение"
            case .active:
                return "Активное движение"
            case .energetic:
                return "Энергичное движение"
            }
        }
        
        var color: String {
            switch self {
            case .calm:
                return "blue"
            case .moderate:
                return "green"
            case .active:
                return "orange"
            case .energetic:
                return "red"
            }
        }
    }
    
    init() {
        setupMotionManager()
    }
    
    private func setupMotionManager() {
        operationQueue.maxConcurrentOperationCount = 1
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.gyroUpdateInterval = updateInterval
    }
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }
        
        isMotionActive = true
        
        motionManager.startDeviceMotionUpdates(to: operationQueue) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else { return }
            
            DispatchQueue.main.async {
                self.processMotionData(motion)
            }
        }
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isMotionActive = false
        
        DispatchQueue.main.async {
            self.motionIntensity = .calm
            self.accelerationMagnitude = 0.0
            self.gyroscopeMagnitude = 0.0
        }
    }
    
    private func processMotionData(_ motion: CMDeviceMotion) {
        // Вычисляем магнитуду ускорения
        let acceleration = motion.userAcceleration
        let accelMagnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )
        
        // Вычисляем магнитуду угловой скорости
        let rotation = motion.rotationRate
        let gyroMagnitude = sqrt(
            rotation.x * rotation.x +
            rotation.y * rotation.y +
            rotation.z * rotation.z
        )
        
        // Применяем сглаживание
        smoothedAcceleration = smoothedAcceleration * (1 - smoothingFactor) + accelMagnitude * smoothingFactor
        smoothedGyroscope = smoothedGyroscope * (1 - smoothingFactor) + gyroMagnitude * smoothingFactor
        
        // Обновляем опубликованные значения
        accelerationMagnitude = smoothedAcceleration
        gyroscopeMagnitude = smoothedGyroscope
        
        // Определяем общую интенсивность движения
        let combinedIntensity = (smoothedAcceleration * 0.7) + (smoothedGyroscope * 0.3)
        let newIntensity = determineMotionIntensity(from: combinedIntensity)
        
        if newIntensity != motionIntensity {
            motionIntensity = newIntensity
            motionIntensitySubject.send(newIntensity)
        }
    }
    
    private func determineMotionIntensity(from magnitude: Double) -> MotionIntensity {
        switch magnitude {
        case 0..<calmThreshold:
            return .calm
        case calmThreshold..<moderateThreshold:
            return .moderate
        case moderateThreshold..<activeThreshold:
            return .active
        default:
            return .energetic
        }
    }
    
    // Методы для калибровки порогов
    func calibrateThresholds() {
        // Здесь можно реализовать логику калибровки на основе
        // данных пользователя или автоматической настройки
    }
    
    deinit {
        stopMotionUpdates()
    }
}