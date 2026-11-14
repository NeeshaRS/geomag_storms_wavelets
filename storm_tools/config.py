"""Loaders for the shared config/paths.json and config/events.json registry."""
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_DIR = REPO_ROOT / "config"


def load_paths():
    """Return the paths.json contents as a dict, with data_root/figure_root as Path objects."""
    paths_file = CONFIG_DIR / "paths.json"
    if not paths_file.exists():
        raise FileNotFoundError(
            f"{paths_file} not found -- copy config/paths.example.json to "
            "config/paths.json and set the paths for your machine.")
    with open(paths_file) as f:
        paths = json.load(f)
    paths["data_root"] = Path(paths["data_root"])
    paths["processed_data_root"] = Path(paths["processed_data_root"])
    paths["figure_root_paper"] = Path(paths["figure_root_paper"])
    paths["dst_index_path"] = paths["data_root"] / paths["dst_index_dir"]
    paths["high_frequency_path"] = paths["data_root"] / paths["high_frequency_dir"]
    # Where Data_processing.m / Network_event_plotting.m / Greenland_event_plotting.m
    # write their cleaned Hhpf CSVs -- travels with this machine, not the raw drive.
    paths["processed_high_frequency_path"] = paths["processed_data_root"] / paths["high_frequency_dir"]
    return paths


def load_events():
    """Return the full list of event dicts from events.json."""
    with open(CONFIG_DIR / "events.json") as f:
        return json.load(f)


def get_event(event_id):
    """Return a single event dict by id (e.g. '1989-03-13'), or raise KeyError."""
    for e in load_events():
        if e["id"] == event_id:
            return e
    raise KeyError(f"No event with id '{event_id}' in config/events.json")
