"""The partial-pass reproduction for corpus#15.

Fourteen tests over `partial.py`: two pass, twelve fail. `pytest -q` reports

    2 passed, 12 failed

and exits 1. An accept that scores on the runner's exit status calls that RED, which
is correct — twelve of fourteen assertions do not hold. An accept that scores by
`grep -qE '[1-9][0-9]* passed'` matches the substring `2 passed` and calls it GREEN.

That is not a hypothetical: it is how `python-react` shipped 2-passed/12-failed and
scored GREEN, which is the observation corpus#15 was filed on.

Fixture data for `ci/verify-accept-oracle.sh` check E. Not a corpus node.
"""

import unittest

from partial import ComputeCell, InputCell


class PartialPassTest(unittest.TestCase):
    # --- the two that pass -------------------------------------------------
    def test_input_cell_has_value(self):
        self.assertEqual(InputCell(10).value, 10)

    def test_input_cell_value_is_settable(self):
        cell = InputCell(4)
        cell.value = 20
        self.assertEqual(cell.value, 20)

    # --- the twelve that fail ----------------------------------------------
    # Each exercises ComputeCell, which is unimplemented and raises.
    def test_compute_cell_one_input(self):
        self.assertEqual(ComputeCell([InputCell(1)], lambda i: i[0] + 1).value, 2)

    def test_compute_cell_two_inputs(self):
        self.assertEqual(ComputeCell([InputCell(1), InputCell(2)], sum).value, 3)

    def test_compute_cell_of_compute_cell(self):
        inner = ComputeCell([InputCell(1)], lambda i: i[0] + 1)
        self.assertEqual(ComputeCell([inner], lambda i: i[0] * 2).value, 4)

    def test_compute_cell_updates_on_input_change(self):
        source = InputCell(1)
        cell = ComputeCell([source], lambda i: i[0] + 1)
        source.value = 3
        self.assertEqual(cell.value, 4)

    def test_compute_cell_updates_transitively(self):
        source = InputCell(1)
        inner = ComputeCell([source], lambda i: i[0] + 1)
        outer = ComputeCell([inner], lambda i: i[0] * 2)
        source.value = 3
        self.assertEqual(outer.value, 8)

    def test_callback_fires_on_change(self):
        source = InputCell(1)
        cell = ComputeCell([source], lambda i: i[0] + 1)
        seen = []
        cell.add_callback(seen.append)
        source.value = 3
        self.assertEqual(seen, [4])

    def test_callback_does_not_fire_without_change(self):
        source = InputCell(1)
        cell = ComputeCell([source], lambda i: i[0] + 1)
        seen = []
        cell.add_callback(seen.append)
        source.value = 1
        self.assertEqual(seen, [])

    def test_callbacks_fire_only_once(self):
        source = InputCell(1)
        cell = ComputeCell([source], lambda i: i[0] + 1)
        seen = []
        cell.add_callback(seen.append)
        source.value = 2
        self.assertEqual(len(seen), 1)

    def test_removed_callback_does_not_fire(self):
        source = InputCell(1)
        cell = ComputeCell([source], lambda i: i[0] + 1)
        seen = []
        cell.add_callback(seen.append)
        cell.remove_callback(seen.append)
        source.value = 3
        self.assertEqual(seen, [])

    def test_multiple_callbacks(self):
        source = InputCell(1)
        cell = ComputeCell([source], lambda i: i[0] + 1)
        a, b = [], []
        cell.add_callback(a.append)
        cell.add_callback(b.append)
        source.value = 3
        self.assertEqual((a, b), ([4], [4]))

    def test_callbacks_not_called_on_intermediate_values(self):
        source = InputCell(1)
        plus_one = ComputeCell([source], lambda i: i[0] + 1)
        minus_one = ComputeCell([source], lambda i: i[0] - 1)
        seen = []
        ComputeCell([plus_one, minus_one], lambda i: i[0] * i[1]).add_callback(seen.append)
        source.value = 4
        self.assertEqual(seen, [15])

    def test_compute_cell_value_is_not_settable(self):
        cell = ComputeCell([InputCell(1)], lambda i: i[0] + 1)
        with self.assertRaises(AttributeError):
            cell.value = 99


if __name__ == "__main__":
    unittest.main()
