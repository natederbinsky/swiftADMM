# ADMM

Implements the Alternating Direction Method of Multipliers (ADMM) and Three-Weight Algorithm (TWA).

See example applications (Sudoku and Circle Packing), but basic usage:

1. Create an `ObjectiveGraph`.
2. Use the `createVariable` method to instantiate variables with initial values/weights.
3. Use the `createFactor` method to create factors that minimize local sub-objectives; edges (via `createEdge`) provide input/output access to existing variables.
4. Use the `iterate` method to perform one step of minimization on the left, followed by variable-value concur on the right; the `iterations` and `converged` properties provide status.

Between iterations...
- Subscripts can be used to get the value variables, as well as enable/disable factors.
- The `reinitialize` method resets the graph to its initial state (initial values/weights, all factors enabled).

Supplied example of "fast" circle packing shows integration with a spatial index for dynamic graph management, as well as use of callbacks (functions called after iteration/reinitialization).
