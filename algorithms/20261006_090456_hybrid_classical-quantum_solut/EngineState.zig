// Define the `EngineState` struct to store the state of the hybrid engine
struct EngineState {
    pub QuantumEngineState: QuantumEngineState,
    pub ClassicalEngineState: ClassicalEngineState,
}

// Define the `QuantumEngineState` struct to store the state of the quantum engine
struct QuantumEngineState {
    pub quantum_engine_state: QuantumAlgorithmState,
}

// Define the `ClassicalEngineState` struct to store the state of the classical engine
struct ClassicalEngineState {
    pub classical_engine_state: ClassicalAlgorithmState,
}
