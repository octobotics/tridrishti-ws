import csv
import re
import shutil
import subprocess
import time
from pathlib import Path

import ecal.nanobind_core as ecal
from ecal.nanobind_core import monitoring

# eCAL's Python 6 bindings do not expose the component constants.  The
# monitoring bit is 0x008; enable every component (0x03F) for discovery.
ECAL_INIT_ALL = 0x03F
OUTPUT_DIR = Path(__file__).with_name("ecal_topology")
SIGNATURE_SUFFIX = re.compile(r"__sig_[0-9a-f]+__plane_(?:local|network)$")


def node_name(entity):
    """Return the eCAL unit name, falling back to the process name."""
    return entity.unit_name or entity.process_name


def logical_topic_name(topic_name):
    """Remove i2w's transport signature so related endpoints share one label."""
    return SIGNATURE_SUFFIX.sub("", topic_name)


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def dot_quote(value):
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_graph(output_dir, nodes, topic_rows, service_rows):
    """Write a Graphviz diagram, then render it as SVG when Graphviz is present."""
    dot_path = output_dir / "ecal_topology.dot"
    graph_lines = [
        "digraph ecal_topology {",
        "  graph [rankdir=LR, bgcolor=white, pad=0.3, nodesep=0.35, ranksep=1.2];",
        "  node [fontname=Helvetica, fontsize=10];",
        "  edge [fontname=Helvetica, fontsize=8];",
    ]

    node_ids = {name: f"node_{index}" for index, name in enumerate(sorted(nodes))}
    topic_names = sorted({row["logical_topic"] for row in topic_rows})
    topic_ids = {name: f"topic_{index}" for index, name in enumerate(topic_names)}
    service_names = sorted({row["service"] for row in service_rows})
    service_ids = {name: f"service_{index}" for index, name in enumerate(service_names)}

    for name, identifier in node_ids.items():
        graph_lines.append(
            f"  {identifier} [label={dot_quote(name)}, shape=box, style=filled, fillcolor=lightblue];"
        )
    for name, identifier in topic_ids.items():
        graph_lines.append(
            f"  {identifier} [label={dot_quote(name)}, shape=ellipse, style=filled, fillcolor=lightgoldenrod1];"
        )
    for name, identifier in service_ids.items():
        graph_lines.append(
            f"  {identifier} [label={dot_quote(name)}, shape=component, style=filled, fillcolor=mistyrose];"
        )

    # A publisher writes to a topic; a subscriber reads from one.
    for row in topic_rows:
        node = node_ids[row["node"]]
        topic = topic_ids[row["logical_topic"]]
        if row["direction"] == "publisher":
            graph_lines.append(f"  {node} -> {topic} [color=forestgreen, label=\"publishes\"];")
        else:
            graph_lines.append(f"  {topic} -> {node} [color=royalblue, label=\"subscribes\"];")
    for row in service_rows:
        graph_lines.append(
            f"  {node_ids[row['node']]} -> {service_ids[row['service']]} "
            f"[color=firebrick, label={dot_quote(row['method'])}];"
        )

    graph_lines.append("}")
    dot_path.write_text("\n".join(graph_lines) + "\n", encoding="utf-8")

    dot = shutil.which("dot")
    if dot:
        svg_path = output_dir / "ecal_topology.svg"
        subprocess.run([dot, "-Tsvg", str(dot_path), "-o", str(svg_path)], check=True)
        return svg_path
    return dot_path


def export_topology(topology):
    """Save raw data in CSV form and its relationships as a Graphviz diagram."""
    OUTPUT_DIR.mkdir(exist_ok=True)
    node_rows = {}
    topic_rows = []
    service_rows = []

    for direction, topics in (
        ("publisher", topology.publishers),
        ("subscriber", topology.subscribers),
    ):
        for topic in topics:
            name = node_name(topic)
            node_rows[name] = {
                "node": name,
                "host": topic.host_name,
                "process_id": topic.process_id,
            }
            topic_rows.append({
                "direction": direction,
                "node": name,
                "logical_topic": logical_topic_name(topic.topic_name),
                "ecal_topic": topic.topic_name,
                "host": topic.host_name,
                "process_id": topic.process_id,
            })

    for server in topology.servers:
        name = node_name(server)
        node_rows[name] = {
            "node": name,
            "host": server.host_name,
            "process_id": server.process_id,
        }
        for method in server.methods:
            service_rows.append({
                "node": name,
                "service": server.service_name,
                "method": method.method_name,
                "host": server.host_name,
                "process_id": server.process_id,
            })

    write_csv(OUTPUT_DIR / "nodes.csv", ["node", "host", "process_id"], node_rows.values())
    write_csv(
        OUTPUT_DIR / "topics.csv",
        ["direction", "node", "logical_topic", "ecal_topic", "host", "process_id"],
        topic_rows,
    )
    write_csv(
        OUTPUT_DIR / "services.csv",
        ["node", "service", "method", "host", "process_id"],
        service_rows,
    )
    graph_path = write_graph(OUTPUT_DIR, node_rows, topic_rows, service_rows)
    print(f"\nWrote CSV files and topology diagram to: {OUTPUT_DIR}")
    print(f"Open the visual map: {graph_path}")


def generate_ecal_map():
    # eCAL 6 initializes with the unit name as its first argument. The old
    # ``ecal.core`` API accepted argv here, but is deprecated.
    if not ecal.initialize("ecal_topology_mapper", ECAL_INIT_ALL):
        raise RuntimeError("Unable to initialize eCAL")

    try:
        # Give the discovery manager a brief moment to receive multicast data.
        print("Collecting live eCAL topology data...")
        time.sleep(2.0)
        topology = monitoring.get_monitoring()

        print("\n=== NODES ===")
        nodes = {
            node_name(entity)
            for entity in (
                list(topology.publishers)
                + list(topology.subscribers)
                + list(topology.servers)
            )
            if node_name(entity)
        }
        for node in sorted(nodes):
            print(f"Node: {node}")

        print("\n=== TOPIC MAP ===")
        for direction, topics in (
            ("PUBLISHER", topology.publishers),
            ("SUBSCRIBER", topology.subscribers),
        ):
            for topic in topics:
                print(
                    f"[{direction}] Node: {node_name(topic)} "
                    f"<--> Topic: {topic.topic_name}"
                )

        print("\n=== SERVICES MAP ===")
        for server in topology.servers:
            for method in server.methods:
                print(
                    f"[SERVICE] Node: {node_name(server)} "
                    f"Exposes Method: {method.method_name}"
                )

        export_topology(topology)
    finally:
        ecal.finalize()

if __name__ == "__main__":
    generate_ecal_map()
