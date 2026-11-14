# geomag_storms_wavelets

Code used for the data processing, wavelet analysis, and figures in:

> Schnepf, N. R., Waghule, B., Love, J. J., & Willer, A. N. (submitted).
> *Equatorward Expansion of Wavelet Power During Severe Geomagnetic Storms.*
> Geophysical Research Letters.

The analysis covers three severe geomagnetic storms (March 1989, October
2003, May 2024) using ground magnetometer data from the IMAGE, CARISMA, and
DTU (Greenland) arrays and the Ottawa observatory, together with the Dst index.

MATLAB handles data ingestion, cleaning, station maps, and the
power/Dst figures. Python (`storm_tools/`) handles the wavelet transform and
scale-averaged power, using [PyCWT](https://pycwt.readthedocs.io).

No data are included in this repository. Data sources are listed in the
paper's Open Research section; the expected file layout and formats are
described below.

## Requirements

- **MATLAB** (developed with R2025b/R2026a), with the Mapping Toolbox (station maps) and
  Signal Processing Toolbox (high-pass filter).
- **Python** 3.12 with the packages in `requirements.txt`:
  ```bash
  pip install -r requirements.txt
  ```

## Setup

1. Copy `config/paths.example.json` to `config/paths.json` and set:
   - `data_root`: folder holding the raw data (layout below)
   - `processed_data_root`: folder for cleaned/intermediate outputs
   - `figure_root_paper`: folder for the paper figures
2. Run all MATLAB and Python scripts with the repository root as the
   working directory.

`config/events.json` defines each event: time windows, which networks to
read and from which files, QC settings (`max_gap_minutes`, `exclude_sites`,
per-station start/end overrides), and wavelet parameters.
`config/event_landmarks_geo_info*.csv` lists the power-system failure
locations and times (with literature sources) marked on the maps and heatmaps.

## Pipeline (per event, run in order)

Each script selects its event near the top (`event_idx` in the MATLAB
scripts, `EVENT_ID` in `Run_Wavelet_Analysis.py`).

0. `Calc_IGRF_CDMlatlon.ipynb` — centered-dipole magnetic latitude/longitude
   (IGRF-14, at each event's epoch) for the stations and map landmarks.
1. `Data_processing.m` — reads each network's raw files, merges them into
   one per-station structure with coordinates attached, and saves
   `<prefix>_united_data.mat` to `processed_data_root`.
2. `Network_event_plotting.m` (set `network` to `"IMAGE"`, `"CARISMA"`, or
   `"OTT"`) and `Greenland_event_plotting.m` — per-network cleaning (spike
   removal, gap handling under `max_gap_minutes`), stacked plots, and the
   high-pass-filtered `*_Hhpf.csv` files used by the wavelet step.
3. `Map_Events.m` — station maps colored by magnetic latitude.
4. `Run_Wavelet_Analysis.py` — wavelet transform and scale-averaged power per
   station; writes plots plus power statistics/time-series CSVs.
5. `Cache_Dst_Locally.m` then `stats_plots_1989.m`, `stats_plots_2003.m`,
   `stats_plots_2024.m` — power vs. magnetic latitude, time, and Dst.

`Assess_Gap_Lengths.m` is a diagnostic that reports the longest internal
data gap per station, used to set the `max_gap_minutes` rule.

## Data layout and formats

Paths below are relative to `data_root/<high_frequency_dir>` unless noted;
file and folder names for each event are set in the `ingestion` block of
`config/events.json`.

| Source | Location | Format |
|---|---|---|
| IMAGE | `Image/<image_fname>` | IMAGE text export: 2 header lines (column names, dashed separator), then rows of `YYYY MM DD HH MM SS` followed by X, Y, Z (nT) for each station. Fill value 99999.9. |
| CARISMA | `<carisma.subdir>/` | Daily `YYYYMMDDSITE.MAG` files (`ftype: "mag"`) or `YYYYMMDDSITE.F01` files (`ftype: "F01"`), as distributed by CARISMA. |
| DTU / Greenland | `<greenland_raw.subdir>/` | IAGA-2002 `.sec` or `.20s` files (`format: "sec"`), or, for 1989, one subfolder per station of CDF files with `Hvar20sec`/`Dvar20sec`/`Zvar20sec` variables (`format: "cdf"`). |
| Ottawa (OTT) | `<ott.subdir>/<ott.fname>` | MATLAB `.mat` file with variables `datetime_vector` (datetime), `x`, `y`, `z` (nT). |
| Station coordinates | `<prefix>_event_sites_geo_info.csv` | One row per station with columns `site`, `lat`, `lon` (geographic), plus `cgm_lat`, `cgm_lon`. Step 0 adds `cdm_lat`, `cdm_lon` and writes `<prefix>_event_sites_geo_info_with_cdm.csv`. |
| Dst | `data_root/<dst_index_dir>/` | WDC Kyoto hourly Dst text files `Dst_1982-2000.txt` and `Dst_2000-2024.txt`, and `Dst2024.mat` with variables `dst_time` and `Dst`. |

The raw-data readers save a `.mat` cache (`cache_fname`) next to the raw
files on first read.

## License

MIT; see `LICENSE`. `matlab_functions/plasma.m` is third-party code
(Stephen Cobeldick) under the BSD-3-Clause license; see `LICENSE-plasma`.

## Citation

Please cite the archived release on Zenodo (see `CITATION.cff`).
