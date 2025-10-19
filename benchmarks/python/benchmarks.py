"""
HAMT Performance Benchmarks for Airspeed Velocity
"""

import subprocess
import os
from typing import Literal


class HAMTBenchmarks:
    """HAMT performance benchmarks using Mojo's internal timing"""

    timeout: int = 300

    def _run_mojo_benchmark(
        self, measurement: Literal["insert", "query"], scale: int
    ) -> float:
        """
        Run the Mojo benchmark and return ops/sec.

        Args:
            measurement: Type of operation ("insert" or "query")
            scale: Number of items to benchmark

        Returns:
            Operations per second as a float

        Raises:
            subprocess.CalledProcessError: If benchmark execution fails
            subprocess.TimeoutExpired: If benchmark exceeds timeout
        """
        # Go up 3 levels: benchmarks.py -> python -> benchmarks -> project root
        root_dir = os.path.dirname(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )

        result = subprocess.run(
            [
                "pixi",
                "run",
                "mojo",
                "run",
                "-I",
                "src/mojo",
                "benchmarks/mojo/bench_numbers.mojo",
                measurement,
                str(scale),
            ],
            cwd=root_dir,
            capture_output=True,
            text=True,
            check=True,
            timeout=self.timeout,
        )

        return float(result.stdout.strip())

    def track_insert_1k(self) -> float:
        """Insert 1,000 sequential integer keys"""
        return self._run_mojo_benchmark("insert", 1000)

    track_insert_1k.unit = "ops/sec"

    def track_insert_10k(self) -> float:
        """Insert 10,000 sequential integer keys"""
        return self._run_mojo_benchmark("insert", 10000)

    track_insert_10k.unit = "ops/sec"

    def track_query_1k(self) -> float:
        """Query 1,000 existing keys"""
        return self._run_mojo_benchmark("query", 1000)

    track_query_1k.unit = "ops/sec"

    def track_query_10k(self) -> float:
        """Query 10,000 existing keys"""
        return self._run_mojo_benchmark("query", 10000)

    track_query_10k.unit = "ops/sec"
