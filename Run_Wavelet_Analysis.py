"""Run_Wavelet_Analysis.py
Consolidates 19890313_Storm_Analysis.ipynb / 20031029_Storm_Analysis.ipynb /
20081120_Quiet_Analysis.ipynb into one registry-driven script. Reads the
cleaned Hhpf CSVs written by Network_event_plotting.m / Greenland_event_plotting.m
(in Data_local), runs the wavelet/scale-averaged-power pipeline per network,
and writes plots + power stats/timeseries -- all parameterized from
config/events.json instead of hardcoded per-storm values.
"""
import matplotlib
matplotlib.use("Agg")  # non-interactive backend -- avoids plt.show() blocking on a GUI window in batch runs

import numpy as np
import pandas as pd
from pathlib import Path

from storm_tools import config
from storm_tools import geomag_wavelets as magwave

# ---- 1) SELECT EVENT ----
EVENT_ID = "1989-03-13"

# The MATLAB scripts' `network` variable doesn't always match the output
# filename: Greenland_event_plotting.m always writes "Greenland" regardless
# of the source label being "DTU" in config/events.json's networks list.
NETWORK_FILE_LABELS = {
    "IMAGE": "IMAGE",
    "DTU": "Greenland",
    "OTT": "OTT",
    "CARISMA": "CARISMA",
}

paths = config.load_paths()
event = config.get_event(EVENT_ID)
tag = EVENT_ID[:4]  # e.g. "1989"

print(f"=== Wavelet analysis for {EVENT_ID}: {event['description']} ===")

wv = event.get("wavelet")
if wv is None:
    raise ValueError(
        f"Event {EVENT_ID} has no 'wavelet' config in config/events.json -- "
        "set min_period_s/max_period_s/peak_height_threshold/etc. before running."
    )
min_period = wv["min_period_s"]
max_period = wv["max_period_s"]
peak_height_threshold = wv["peak_height_threshold"]
h_timeseries_ylim = tuple(wv["h_timeseries_ylim"]) if wv.get("h_timeseries_ylim") else None
scale_avg_power_ylim = tuple(wv["scale_avg_power_ylim"]) if wv.get("scale_avg_power_ylim") else None

# Tag all outputs with the effective max_period so a future one-off
# comparison run wouldn't silently overwrite these files.
if max_period >= 3600:
    period_tag = f"maxT{max_period/3600:g}hr"
else:
    period_tag = f"maxT{max_period/60:g}min"
print(f"min_period={min_period}s, max_period={max_period}s ({period_tag})")

dst_window = event.get("dst_window")
if dst_window is None:
    raise ValueError(f"Event {EVENT_ID} has no 'dst_window' in config/events.json -- needed for peak/integrated power.")
start_time = np.datetime64(dst_window["start"])
end_time = np.datetime64(dst_window["end"])

# ---- 2) Figure + output directories ----
fig_dir = paths["figure_root_paper"] / event["figure_subdir"] / "wavelet" / period_tag
fig_dir.mkdir(parents=True, exist_ok=True)

wo_data_dir = paths["processed_data_root"] / "WO_data"
power_stats_dir = wo_data_dir / "power_stats"
power_ts_dir = wo_data_dir / "power_timeseries"
power_stats_dir.mkdir(parents=True, exist_ok=True)
power_ts_dir.mkdir(parents=True, exist_ok=True)

# ---- 3) Find each configured network's cleaned Hhpf CSV ----
networks = event["networks"]
print(f"Networks configured for this event: {networks}")

all_stats = []

for network in networks:
    file_label = NETWORK_FILE_LABELS.get(network, network)
    csv_path = paths["processed_high_frequency_path"] / network / f"{tag}_{file_label}_Hhpf.csv"
    if not csv_path.exists():
        # try the file_label as the folder name too (matches Network_event_plotting.m's own out_dir naming)
        csv_path = paths["processed_high_frequency_path"] / file_label / f"{tag}_{file_label}_Hhpf.csv"
    if not csv_path.exists():
        print(f"  [{network}] No Hhpf CSV found at expected path ({csv_path}) -- skipping. "
              f"Has Network_event_plotting.m / Greenland_event_plotting.m been run for this network yet?")
        continue

    print(f"\n--- {network}: {csv_path.name} ---")
    df = pd.read_csv(csv_path)
    df["time"] = df["time"].to_numpy(dtype="datetime64[s]")

    # a) Wavelet + inverse-transform + scale-averaged-power plots, one per station
    magwave.wavelet_plots_by_df(
        df, min_period, max_period, fig_dir,
        h_timeseries_ylim=h_timeseries_ylim,
        scale_avg_power_ylim=scale_avg_power_ylim,
    )

    # b) Per-station scale-averaged power timeseries -> CSV
    power_ts_df = magwave.get_power_timeseries_bydf(df, min_period, max_period)
    ts_path = power_ts_dir / f"{tag}_{file_label}_storm_power_timeseries_{period_tag}.csv"
    power_ts_df.to_csv(ts_path, index=False)
    print(f"Wrote power timeseries: {ts_path}")

    # c) Integrated power + top-3 peaks per station -> combined stats
    stats_df = magwave.get_power_info_bydf(df, min_period, max_period, start_time, end_time, peak_height_threshold)
    stats_df["network"] = network
    all_stats.append(stats_df)

# ---- 4) Combined power stats across all networks ----
if all_stats:
    combined_stats = pd.concat(all_stats)
    stats_path = power_stats_dir / f"{tag}_storm_power_stats_{period_tag}.csv"
    combined_stats.to_csv(stats_path)
    print(f"\nWrote combined power stats: {stats_path}")
else:
    print("\nNo networks produced output -- nothing written.")
