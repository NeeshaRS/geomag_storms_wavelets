import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import pycwt as wavelet
from pycwt.helpers import find
from scipy.signal import find_peaks

def _trim_nan_edges(t, y):
    """Trim a station's series to its valid (non-NaN) span, wherever it falls.

    A station whose real coverage starts late and/or ends before the event's
    common time grid gets leading/trailing-NaN-padded out to that grid on the
    MATLAB side (matches F_interpNans's own behavior for the same reason).
    pycwt's wavelet.ar1() can't handle NaN in the series ("Series is too
    short or trend is too large"), so trim before any wavelet computation
    rather than crash -- same fix F_HPF already needed on the MATLAB side
    for the same cause.

    Returns (t_trim, y_trim, first_valid) -- first_valid is the index the
    valid span started at in the original array, so a caller re-aligning a
    computed result back onto the original grid doesn't have to assume it
    started at 0 (that assumption previously shifted a late-starting
    station's power values to the wrong dates, same bug fixed in the
    MATLAB scripts 2026-08-19 -- see Network_event_plotting.m/
    Greenland_event_plotting.m for the equivalent fix).
    """
    valid = ~np.isnan(y)
    if valid.all():
        return t, y, 0
    if not valid.any():
        raise ValueError("Station's series is entirely NaN.")
    idx = np.where(valid)[0]
    first_valid, last_valid = idx[0], idx[-1]
    if not valid[first_valid:last_valid + 1].all():
        raise ValueError(
            "Station's series has internal NaN gaps, not just a leading/"
            "trailing pad -- unexpected (max_gap_minutes should have "
            "dropped or fully interpolated it upstream), needs investigation."
        )
    return t[first_valid:last_valid + 1], y[first_valid:last_valid + 1], first_valid


def get_power_info_bydf(df, min_period, max_period, start_time, end_time, peak_height_threshold):
    """
    For a given dataframe df, a minimum period and maximum period, and a start/end time, calculate the integrated
    power between the start/end time, the 3 max power values and their times. Return a dataframe with this information
    for each station.

    :param df: observatory dataframe with columns 'time' and columns of station data
    :param min_period: number denoting the minimum period in seconds
    :param max_period: number denoting the maximum period in seconds
    :param start_time: start time (numpy timestamp)
    :param end_time: end time (numpy timestamp)
    :param peak_height_threshold: minimum scale-averaged power for a local maximum to
        count as a "peak" (event-specific -- from config/events.json's wavelet.peak_height_threshold)
    :return:
    """

    # Get the list of station names (all columns except 'time')
    stations = df.columns.drop('time')

    # Make array of the timestamps
    t = df['time'].to_numpy()

    # Dictionary to hold all max values dataframes for each station
    max_values_dict = {}

    # Loop through each station and get the power stats
    for station in stations:
        y = df[station].to_numpy()
        integral, max_values, max_times, scale_avg= get_power_info_bystation(t, y, station, min_period, max_period, start_time, end_time, peak_height_threshold)

        # Create a dictionary to hold the power stats
        power_stats_data = {
            'integrated_power': integral,
            'max_value_1': [max_values[0]],
            'max_value_2': [max_values[1]],
            'max_value_3': [max_values[2]],
            'max_time_1': [max_times[0]],
            'max_time_2': [max_times[1]],
            'max_time_3': [max_times[2]]
        }

        # Create a dataframe for this station's power stats
        # and set the station code as the index
        max_values_df = pd.DataFrame(power_stats_data, index=[station])

        # Store the dataframes in the dictionary with the station code as the key
        max_values_dict[station] = max_values_df

    # Combine all individual station dataframes into a single dataframe
    combined_max_values_df = pd.concat(max_values_dict.values())


    return combined_max_values_df


def get_power_bystation(t, y, station, min_period, max_period):
    """
        For a given station and it's data (y and t), a minimum period and maximum period, and a start/end time,
        calculate the scale averaged power for the wavelet transform.

        :param t: the data's timestamps
        :param y: the station's data
        :param station: 3 character string of the station code
        :param min_period: number denoting the minimum period in seconds
        :param max_period: number denoting the maximum period in seconds

        :return:
        scale_avg: scale averaged power
        """
    n_full = len(y)
    t_trim, y_trim, first_valid = _trim_nan_edges(t, y)

    dat_norm, std = normalize_data(y_trim)
    iwave, period, wave, power, scales, alpha, dt, mother, coi = wavelet_transform(y_trim, t_trim, std)
    print(f'Wavelet transform complete for {station}.')
    scale_avg_signif, scale_avg = scale_average(min_period, max_period, period, dt, y_trim, scales, std, power, mother,
                                                alpha)
    print(f'Scale averaged calculated for {station}.')

    # Pad back out to the original (full common-grid) length with NaN, at
    # the correct offset -- so callers keeping this aligned against the
    # untrimmed t (e.g. the power-timeseries CSV, or
    # get_power_info_bystation's window mask below) don't need to know a
    # trim happened. Pasting at the trim's true start (first_valid) rather
    # than always at 0 matters for any station whose valid span doesn't
    # begin at the very start of the common grid.
    if len(scale_avg) < n_full:
        padded = np.full(n_full, np.nan)
        padded[first_valid:first_valid + len(scale_avg)] = scale_avg
        scale_avg = padded

    return scale_avg


def get_power_timeseries_bydf(df, min_period, max_period):
    """
    For each station column in df, compute the scale-averaged wavelet power timeseries.
    Consolidates a loop that was previously copy-pasted across the three
    per-storm notebooks. Returns a new dataframe: 'time' plus one
    '<station>_scale_avg_power' column per station.

    :param df: dataframe with column 'time' and one column per station
    :param min_period: number denoting the minimum period in seconds
    :param max_period: number denoting the maximum period in seconds
    :return: dataframe of per-station scale-averaged power timeseries
    """
    stations = df.columns.drop('time')
    t = df['time'].to_numpy()
    out = pd.DataFrame({'time': df['time']})
    for station in stations:
        y = df[station].to_numpy()
        out[f'{station}_scale_avg_power'] = get_power_bystation(t, y, station, min_period, max_period)
    return out


def get_power_info_bystation(t, y, station, min_period, max_period, start_time, end_time, peak_height_threshold):
    """
    For a given station and it's data (y and t), a minimum period and maximum period, and a start/end time, calculate
    the integrated power between the start/end time, the 3 max power values and their times. Return numpy arrays with
    this information.

    :param t: the data's timestamps
    :param y: the station's data
    :param station: 3 character string of the station code
    :param min_period: number denoting the minimum period in seconds
    :param max_period: number denoting the maximum period in seconds
    :param peak_height_threshold: minimum scale-averaged power for a local maximum to count as a "peak"

    :return:
    integral: scale averaged power integrated across the min/max period range
    max_values: the 3 max peak power values within the start/end time
    max_times: the corresponding times of the peak power values
    """
    # Get the scale averaged power
    scale_avg = get_power_bystation(t, y, station, min_period, max_period)

    # Create a mask for the time range
    mask = (t >= start_time) & (t <= end_time)

    # Extract the relevant portions of t and scale_avg. Only the part of the window where the
    # station actually has data counts: leading/trailing NaN (a station that starts late, ends early,
    # or was trimmed) would otherwise turn the whole integral into NaN. Such stations therefore have
    # a partial-window total -- their start/end times are listed in the station tables.
    valid = mask & np.isfinite(scale_avg)
    t_filtered = t[valid]
    scale_avg_filtered = scale_avg[valid]

    # Integrate using the trapezoidal rule
    # np.trapz() requires the x values (time differences) in a numeric format, so we need to convert t_filtered
    if t_filtered.size > 1:
        time_diffs = (t_filtered - t_filtered[0]).astype('timedelta64[s]').astype(float)
        integral = np.trapz(scale_avg_filtered, x=time_diffs)
    else:
        integral = np.nan
    print(f'Total storm power (within window) calculated for {station}: {integral} nT$^2$.')

    # Find all local maxima above the event's peak-height threshold
    peaks, properties = find_peaks(scale_avg, height=peak_height_threshold)

    # Extract peak values
    peak_values = scale_avg[peaks]
    # Sort peaks by height to identify the 3 highest distinct peaks
    max_indices = peaks[np.argsort(peak_values)[-3:]]
    # Get the corresponding largest values
    max_values = scale_avg[max_indices]
    # Get the corresponding times
    max_times = t[max_indices]

    # Fewer than 3 peaks can clear the threshold (e.g. a shorter max_period
    # means less scale-averaged power overall) -- pad out to 3 with NaN
    # instead of assuming 3 peaks always exist.
    n_missing = 3 - len(max_values)
    if n_missing > 0:
        max_values = np.concatenate([max_values, np.full(n_missing, np.nan)])
        max_times = np.concatenate([max_times, np.full(n_missing, np.datetime64('NaT'))])

    print(f'For {station} the top 3 max values are: {max_values}')

    return integral, max_values, max_times, scale_avg


def get_sig_ratio(y, dt, scales, alpha, mother, power):
    """
    Calculate the power spectra significance test. The power is
    significant where the ratio (power / sig95) > 1.

    Inputs:
    scales   the wavelet transform's scales
    alpha    lag-1 autocorrelation for red noise
    dt       the time step
    mother   the mother wavelet being used
    power    the wavelet power

    Outputs:
    sig_ratio   the ratio of power to sig95
    """
    signif, fft_theor = wavelet.significance(1.0, dt, scales, 0, alpha,
                                             significance_level=0.95,
                                             wavelet=mother)

    N = y.size
    sig95 = np.ones([1, N]) * signif[:, None]
    sig_ratio = power / sig95

    return sig_ratio


def normalize_data(y):
    """
    For a dataseries y, normalize it using standard deviation.

    Inputs:
    y   numpy array of data

    Outputs:
    dat_norm    normalized numpy array of data
    std         standard deviation of the data
    """

    std = y.std()  # Standard deviation
    dat_norm = y / std  # Normalized dataset

    return dat_norm, std


def plot_iw_power_scaled(t, y, station, min_period, max_period, figpath,
                          h_timeseries_ylim=None, scale_avg_power_ylim=None,
                          show_normalized=False, show_significance=False, show_coi=False):
    """
    Plot a) the detrended time series and the inverse wavelet transform; b) the normalized
    wavelet power; c) the min-max period scaled-averaged wavelet power. Calculate necessary info along the way.

    :param t: the data's timestamps
    :param y: the station's data
    :param station: 3 character string of the station code
    :param min_period: number denoting the minimum period in seconds
    :param max_period: number denoting the maximum period in seconds
    :param figpath: directory to save the output PNG to (event-specific, from config)
    :param h_timeseries_ylim: optional (min, max) tuple for subplot (a)'s y-axis.
        Event-specific -- from config/events.json's wavelet.h_timeseries_ylim. If
        None, matplotlib auto-scales.
    :param scale_avg_power_ylim: optional (min, max) tuple for subplot (c)'s y-axis.
        Event-specific -- from config/events.json's wavelet.scale_avg_power_ylim. If
        None, matplotlib auto-scales.
    :param show_normalized: if True, also plot the normalized (unitless) series in (a).
        Off by default -- it shares the nT axis, so it is misleading there.
    :param show_significance: if True, draw the 95% red-noise significance contours in (b)
        and the scale-averaged 95% significance level in (c). Off by default.
    :param show_coi: if True, shade the cone of influence in (b). Off by default.

    :return:
    plot
    """
    t, y, _ = _trim_nan_edges(t, y)

    dat_norm, std = normalize_data(y)
    iwave, period, wave, power, scales, alpha, dt, mother, coi = wavelet_transform(y, t, std)
    print(f'Wavelet transform complete for {station}.')
    print(f'For the inverse wavelet transform at {station}, the minimum is {np.min(iwave)} and the maximum is {np.max(iwave)}.')
    scale_avg_signif, scale_avg= scale_average(min_period, max_period, period, dt, y, scales, std, power, mother, alpha)
    print(f'Scale averaged calculated for {station}.')
    print(f'The max scaled variance for {station} is {np.max(scale_avg)}.')
    sig_ratio= get_sig_ratio(y, dt, scales, alpha, mother, power)

    # Prepare the figure
    plt.close('all')
    plt.ioff()
    figprops = dict(figsize=(11, 8), dpi=72)
    fig = plt.figure(**figprops)

    # 1st SUB PLOT ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
    # The original time series anomaly and inverse wavelet transform.

    ax1 = plt.axes([0.1, 0.7, 0.65, 0.3])
    ax1.plot(t, y, 'k', linewidth=1, label='high-pass filtered H')
    if show_normalized:
        ax1.plot(t, dat_norm, '-', linewidth=1, color='grey', label='normalized data')
    ax1.plot(t, iwave, '--', linewidth=0.8, color='#7EA172', label='inverse wavelet transform')
    ax1.set_title(f'a) {station} H time series')
    ax1.set_ylabel('H (nT)')
    ax1.legend(loc='center left', bbox_to_anchor=(1, 0.5), ncol=1)
    # Set the y-axis limits (event-specific, from config; auto-scale if not given)
    if h_timeseries_ylim is not None:
        ax1.set_ylim(*h_timeseries_ylim)

    # Set x limits
    ax1.set_xlim([t.min(), t.max()])
    # Remove the x-axis labels
    ax1.tick_params(axis='x', rotation=45, labelbottom=False)  # Hide x-axis tick labels

    # plot grid
    ax1.grid()

    # 2nd SUB PLOT ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
    # The normalized wavelet power spectrum.
    # Note that period's scale is log10.

    ax2 = plt.axes([0.1, 0.35, 0.79, 0.3], sharex=ax1)

    vmin = -4
    vmax = 4

    # Plot of the normalized wavelet power spectrum:
    waveletplot = ax2.contourf(t, np.log10(period), np.log10(power), levels=np.linspace(vmin, vmax, 10),
                               extend='both', cmap=plt.cm.hot)
    extent = [t.min(), t.max(), min(period), max(period)]
    ax2.set_title(f'b) {station} H Wavelet Power Spectrum ({mother.name})')
    ax2.set_ylabel('Period (s)')
    # Set x limits
    ax2.set_xlim([t.min(), t.max()])
    # Remove the x-axis labels
    ax2.tick_params(axis='x', rotation=45, labelbottom=False)  # Hide x-axis tick labels

    # Add the 95% significance contours (toggle: show_significance)
    if show_significance:
        ax2.contour(t, np.log10(period), sig_ratio, [-99, 1], colors='k', linewidths=1,
                   extent=extent)

    # Add shading for the cone of influence (toggle: show_coi)
    if show_coi:
        dt_timedelta = np.timedelta64(int(dt), 's')
        ax2.fill(np.concatenate([t, t[-1:] + dt_timedelta, t[-1:] + dt_timedelta,
                                 t[:1] - dt_timedelta, t[:1] - dt_timedelta]),
                 np.concatenate([np.log10(coi), [np.log10(1e-9)], np.log10(period[-1:]),
                                 np.log10(period[-1:]), [np.log10(1e-9)]]), 'k', alpha=0.3)
    # Mark the upper bound of the scale-averaging band (max_period)
    ax2.axhline(np.log10(max_period), color='w', linestyle='--', linewidth=1.2)

    # Set the y-axis limits to the min and max periods
    ax2.set_ylim(np.log10(period.min()), np.log10(period.max()))

    # plot grid
    ax2.grid()

    # Set the y ticks -- label count must match however many decades this
    # event's period range actually spans (varies with min/max_period and
    # station cadence), not a fixed number.
    Yticks = 10 ** np.arange(np.floor(np.log10(period.min())),
                             np.ceil(np.log10(period.max())) + 1)
    Yticks = Yticks[1:-1]
    ax2.set_yticks(np.log10(Yticks))
    ax2.set_yticklabels([f'10$^{int(np.log10(v))}$' for v in Yticks])

    # Add a colorbar under the plot
    cbar = plt.colorbar(waveletplot, ax=ax2, orientation='vertical', aspect=30, pad=0.02,
                        ticks=np.linspace(vmin, vmax, num=5))
    cbar.set_label(r'$\log_{10}|W_n(s)|^2$')

    # 3rd SUB PLOT ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
    # The scale averaged wavelet spectrum.
    ax3 = plt.axes([0.1, 0.07, 0.65, 0.23], sharex=ax1)
    if show_significance:
        ax3.axhline(scale_avg_signif, color='k', linestyle='--', linewidth=1.)
    ax3.plot(t, scale_avg, 'k-', linewidth=1.5)
    ax3.set_title('c) Wavelet power')
    ax3.set_xlabel('Date (UT)')
    ax3.set_ylabel('Wavelet power (nT$^2$)')
    ax3.set_xlim([t.min(), t.max()])

    # Rotate the x-axis labels
    ax3.tick_params(axis='x', rotation=45)

    # Set the y-axis limits (event-specific, from config; auto-scale if not given)
    if scale_avg_power_ylim is not None:
        ax3.set_ylim(*scale_avg_power_ylim)

    plt.grid()

    # Save the plot as a .png file
    year = t[0].astype('datetime64[Y]').astype(int) + 1970
    fname = f'{year}_{station}_wavelet-plots.png'
    figpath = str(figpath)
    if not figpath.endswith('/'):
        figpath = figpath + '/'
    plt.savefig(f'{figpath}{fname}', format='png', dpi=300, bbox_inches='tight')

    plt.show()

    return


def scale_average(min_period, max_period, period, dt, y, scales, std, power, mother, alpha):
    """
    Calculate the scale average between two given periods.

    Inputs:
    min_period      number denoting the minimum period in seconds
    max_period      number denoting the maximum period in seconds
    period          periods corresponding to the wavelet transform
    dt              the time step
    y               numpy array of data
    scales          the wavelet transform's scales
    std             standard deviation of the data
    power           the wavelet transform's power
    mother          the mother wavelet

    Outputs:
    scale_avg_signif
    scale_avg
    """
    # Select portions of the wavelet transform with period between min_period and max_period
    sel = find((period >= min_period) & (period < max_period))

    # Calculate variance
    var = std**2

    # Number of observations
    N = y.size

    dj = 1 / 12  # Twelve sub-octaves per octaves

    # Calculate the scale average and its significance level
    Cdelta = mother.cdelta
    scale_avg = (scales * np.ones((N, 1))).transpose()
    scale_avg = power / scale_avg  # As in Torrence and Compo (1998) equation 24
    scale_avg = var * dj * dt / Cdelta * scale_avg[sel, :].sum(axis=0)
    scale_avg_signif, tmp = wavelet.significance(var, dt, scales, 2, alpha,
                                                 significance_level=0.95,
                                                 dof=[scales[sel[0]],
                                                      scales[sel[-1]]],
                                                 wavelet=mother)

    return scale_avg_signif, scale_avg


def wavelet_transform(y, t, std):
    """
    For a normalized dataseries dat_norm with timestamps at t, perform the wavelet transform.

    Inputs:
    y          numpy array of data
    t          timeseries array
    std        standard deviation of the data

    Outputs:
    iwave    inverse wavelet transform
    period   periods corresponding to the wavelet transform
    wave     the wavelet transform
    power    the wavelet transform's power
    scales   the wavelet transform's scales
    alpha    lag-1 autocorrelation for red noise
    dt       the time step
    coi      cone of influence
    """

    # Calculate dt for the wavelet transform.
    time_delta = t[1] - t[0]
    dt = time_delta/ np.timedelta64(1, 's') # convert from np nanoseconds to float seconds

    # Set initial scale
    s0 = 2 * dt  # Start with 2x the time step for the minimum scale
    # Set parameters for the wavelet transform
    mother = wavelet.Morlet(6)
    dj = 1 / 12  # Twelve sub-octaves per octaves
    J = 13 / dj  # 13 powers of two with dj sub-octaves
    try:
        alpha, _, _ = wavelet.ar1(y)  # Lag-1 autocorrelation for red noise
    except Warning:
        # pycwt's "unbiased" AR(1) estimator (Allen & Smith 1996) solves a
        # quadratic whose discriminant is a difference of two ~1e16+
        # terms -- for a series with near-unit-root (very high sample-to-
        # sample) autocorrelation, floating-point cancellation can push
        # that discriminant slightly negative, so it has no real root and
        # raises instead of returning a value. Seen across most of this
        # event's CARISMA stations (lag-1 corr ~0.9999+ for 15/16 of
        # them, not specific to any one station) -- fall back to the
        # simple (biased) lag-1 autocorrelation coefficient rather than
        # crash; at this level of autocorrelation the bias correction is
        # negligible anyway.
        x = y - y.mean()
        # np.errstate suppresses spurious overflow/invalid-value warnings
        # from the BLAS backend on large dot products (macOS Accelerate is
        # known to raise these even when the result is a normal finite
        # value -- verified against all of this event's stations, alpha
        # always came out sane).
        with np.errstate(over='ignore', invalid='ignore', divide='ignore'):
            alpha = float((x[:-1] @ x[1:]) / (x @ x))
        print(f"wavelet.ar1 failed (near-unit-root autocorrelation) -- using simple estimate alpha={alpha:.6f}.", flush=True)

    # Normalize the data
    dat_norm, std = normalize_data(y)

    # Perform the wavelet transform on the normalized data.
    wave, scales, freqs, coi, fft, fftfreqs = wavelet.cwt(dat_norm, dt, dj, s0, J, mother)
    print('Performed the wavelet transform on the normalized data.')

    # Since we have normalized our input time-series, we calculate the inverse transform
    # (to obtain a time series) then multiply the inverse transform by the standard deviation.
    iwave = wavelet.icwt(wave, scales, dt, dj, mother) * std
    print('Calculated the inverse wavelet transform.')

    # We calculate the normalized wavelet and Fourier power spectra, as well as the Fourier
    # equivalent periods for each wavelet scale:
    power = (np.abs(wave)) ** 2
    fft_power = np.abs(fft) ** 2
    period = 1 / freqs
    print(f"Minimum period: {min(period)} s, Maximum period: {max(period)} s.")

    return iwave, period, wave, power, scales, alpha, dt, mother, coi


def wavelet_plots_by_df(df, min_period, max_period, figpath,
                         h_timeseries_ylim=None, scale_avg_power_ylim=None,
                         show_normalized=False, show_significance=False, show_coi=False):
    """
    For a given dataframe with a 'time' column and columns for specific stations,
    loop thru each station and call function plot_iw_power_scaled.

    :param df: the dataframe with column 'time' and columns with 'AAA' headers for each geomagnetic station
    :param min_period: number denoting the minimum period in seconds
    :param max_period: number denoting the maximum period in seconds
    :param figpath: directory to save each station's plot to (event-specific, from config)
    :param h_timeseries_ylim: optional (min, max) tuple, event-specific from config
    :param scale_avg_power_ylim: optional (min, max) tuple, event-specific from config
    :return: plot_iw_power_scaled plot for each station
    """

    # Get the list of station names (all columns except 'time')
    stations = df.columns.drop('time')

    # Make array of the timestamps
    t = df['time'].to_numpy()

    # Loop through each station and plot the data
    for station in stations:
        # Pass the time and station data to the plotting function
        y = df[station].to_numpy()
        plot_iw_power_scaled(t, y, station, min_period, max_period, figpath,
                              h_timeseries_ylim=h_timeseries_ylim,
                              scale_avg_power_ylim=scale_avg_power_ylim,
                              show_normalized=show_normalized,
                              show_significance=show_significance,
                              show_coi=show_coi)

    return
