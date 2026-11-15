import json
from pathlib import Path

import pytest

MANIFEST = Path(__file__).parents[1] / "dbt" / "target" / "manifest.json"
TAG = "cross_layer"


def layer_of(node: dict) -> str:
    return Path(node["original_file_path"]).parts[1]


def untagged_cross_layer_tests(manifest: dict) -> list[str]:
    nodes = manifest["nodes"]
    offenders = []
    for node in nodes.values():
        if node["resource_type"] != "test":
            continue
        parents = [
            nodes[uid]
            for uid in node["depends_on"]["nodes"]
            if uid.startswith("model.")
        ]
        spans_layers = len({layer_of(parent) for parent in parents}) > 1
        if spans_layers and TAG not in node["tags"]:
            offenders.append(node["name"])
    return sorted(offenders)


@pytest.mark.skipif(
    not MANIFEST.exists(),
    reason="run `uv run dbt parse` to create dbt/target/manifest.json",
)
def test_tests_spanning_layers_carry_the_cross_layer_tag():
    manifest = json.loads(MANIFEST.read_text())
    assert untagged_cross_layer_tests(manifest) == []
