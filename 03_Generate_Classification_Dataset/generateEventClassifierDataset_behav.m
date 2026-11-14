function [X, y] = generateEventClassifierDataset_behav(tankPath, eventTime1, eventTime2, timewindow, binSize)
%% generateEventClassifierDataset()
% Generates a position-based dataset for the behavior-only classifier.
% For each event, the distance from CENTER is cropped around the event and
% averaged into fixed-width time bins, so every event has the same length.
%
% tankPath   : string. location of tank
% eventTime1 : 1D array. timepoints of event 1 (ms)
% eventTime2 : 1D array. timepoints of event 2 (ms)
% timewindow : [TIMEWINDOW_LEFT(ms), TIMEWINDOW_RIGHT(ms)] default = [-8000, +6000] (ms)
% binSize    : bin width (ms). default = 100
%
% X : (nEvent x nBin) binned distance from CENTER
% y : (nEvent x 1) class label (1 = event 1, 2 = event 2)

arguments
    tankPath string = ""
    eventTime1 double = []
    eventTime2 double = []
    timewindow (1,2) double = [-8000, +6000]
    binSize (1,1) double = 100
end

BASEPATH = "H:\Data\Kim Data";
CENTER = [585, 294]; % x and y

%% Check window / bin setting
nBin = diff(timewindow) / binSize;
if nBin ~= round(nBin)
    error("timewindow length must be a multiple of binSize");
end

%% Get filepaths
if tankPath == ""
    tankPath = uigetdir(BASEPATH);
end

fprintf("generateEventClassifierDataset : Processing tank %s\n", tankPath);
tankName = regexp(tankPath, '\\(?:@)(AP.*)$', 'tokens');
tankName = tankName{1}{1};

%% Get tracking file Paths
trackingFilePaths = glob(tankPath, '\.(N|n)(V|v)(T|t)', true);

%% Load helper file
load(fullfile(tankPath, strcat(tankName, '_helper.mat')));
if ~all([exist('expStat', 'var'), exist('time2TS', 'var'), exist('time2TS_filename', 'var')])
    error("Helper file not loaded properly")
end

%% Read tracking file
fprintf("generateEventClassifierDataset : Loading tracking data\n");

[TimeStamps, x, y] = ... % x in the long axis.
    Nlx2MatVT(...
        trackingFilePaths,...
        [1, 1, 1, 0, 0, 0],...
        0,... %Extract Header
        1,...
        1);

%% Check Our exp start ts with tracking data's ts.
ts = (TimeStamps(:) - expStat.startTS) / 1000; % in ms, column
if abs(ts(1)) > 1 % larger than 1ms
    error("Tracking data's time doesn't match");
end

%% Recover tracking data
tracking = [x(:), y(:)];
invalid = tracking(:,1) < 210;
tracking(invalid, :) = NaN;
tracking = fillmissing(tracking, 'linear', 1, 'EndValues', 'nearest');

%% Distance from CENTER (whole session)
dist = sqrt(sum((tracking - CENTER).^2, 2));
speed = sqrt(sum(diff(tracking, 1).^2, 2));

%% Crop and bin around the events
%warning("Function is using speed, not distance")
%event1_data = binAroundEvents(ts, dist, eventTime1, timewindow, binSize, nBin);
event1_data = binAroundEvents(ts, speed, eventTime1, timewindow, binSize, nBin);
%event1_data = binAroundEvents(ts, tracking(:,1), eventTime1, timewindow, binSize, nBin);
%event2_data = binAroundEvents(ts, dist, eventTime2, timewindow, binSize, nBin);
event2_data = binAroundEvents(ts, speed, eventTime2, timewindow, binSize, nBin);
%event2_data = binAroundEvents(ts, tracking(:,1), eventTime2, timewindow, binSize, nBin);

%% Save Data
X = [event1_data; event2_data];
y = [1*ones(size(event1_data, 1), 1); 2*ones(size(event2_data, 1), 1)];

fprintf('generateEventClassifierDataset : Complete %s\n', tankName)
end

%% ------------------------------------------------------------------------
function data = binAroundEvents(ts, dist, eventTimes, timewindow, binSize, nBin)
% Returns (nValidEvent x nBin). Events whose window falls outside the
% tracking data are skipped.

data = nan(numel(eventTimes), nBin);
keep = false(numel(eventTimes), 1);

for i_time = 1 : numel(eventTimes)
    edges = eventTimes(i_time) + (timewindow(1) : binSize : timewindow(2));

    % Skip if the window is out of range
    if edges(1) < ts(1) || edges(end) > ts(end)
        continue
    end

    % Assign each tracking sample to a bin, then average within bins
    idx = discretize(ts, edges);
    ok = ~isnan(idx);
    binned = accumarray(idx(ok), dist(ok), [nBin, 1], @mean, NaN);

    % Fill bins with no tracking sample (rare at 30 Hz with 100-ms bins)
    binned = fillmissing(binned, 'linear', 'EndValues', 'nearest');

    data(i_time, :) = binned';
    keep(i_time) = true;
end

data = data(keep, :);
end