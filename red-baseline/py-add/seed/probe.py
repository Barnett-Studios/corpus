"""Fixed harness — nodes never edit this file (only `calc.py` is in `files:`).

The only importer of the model-edited `calc`. Computes observations, prints JSON,
asserts nothing. `acceptance_test.py` runs this as a SUBPROCESS and judges the
result, so model code and the assertions never share a process (issue #7).
"""

import json
import sys

from calc import add

json.dump([add(2, 3), add(-1, 1)], sys.stdout)
