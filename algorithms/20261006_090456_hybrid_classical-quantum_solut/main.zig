// Define a `run` function to execute the hybrid algorithm
fn run(state: *AlgorithmState) !void {
    var engine = HybridEngine{
        .quantum_engine = QuantumAlgorithm{},
        .classical_engine = ClassicalAlgorithm{},
    };

    var engine_state = EngineState{
        .quantum_engine_state = QuantumEngineState{},
        .classical_engine_state = ClassicalEngineState{},
    };

    runEngine(&engine, &engine_state);
}
