"""Fixture implementation for the partial-pass reproduction (corpus#15).

Deliberately half-finished, in the shape a model's first attempt lands in: the two
trivial entry points work, the twelve that carry the actual task raise. The suite
therefore emits `2 passed, 12 failed` — the exact runner output that scored
`python-react` GREEN under a `grep -qE '[1-9][0-9]* passed'` accept.

Fixture data for `ci/verify-accept-oracle.sh` check E. Not a corpus node; never
appears under `red-baseline/`.
"""


class InputCell:
    """The trivial part a partial attempt does get right."""

    def __init__(self, value):
        self.value = value


class ComputeCell:
    """The part that carries the task. Unimplemented."""

    def __init__(self, inputs, compute_function):
        raise NotImplementedError("ComputeCell is not implemented")

    def add_callback(self, callback):
        raise NotImplementedError("add_callback is not implemented")

    def remove_callback(self, callback):
        raise NotImplementedError("remove_callback is not implemented")
