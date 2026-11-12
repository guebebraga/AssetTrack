"""Generación de identificadores con el mismo estilo que el frontend."""

import itertools
import time

_counter = itertools.count(1)


def new_id(prefix: str) -> str:
    """Genera un ID único legible, por ejemplo AST-1A2B3C-001."""
    stamp = format(time.time_ns() // 1_000, "X")
    return f"{prefix}-{stamp}-{next(_counter):03d}"
