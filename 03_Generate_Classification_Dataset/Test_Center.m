%% Generate_Classification_Dataset
% 2026 Ji Hoon Jeong
% Script for tank batch

%% Set Variables
BASEPATH = "H:\Data\Kim Data";

%% Get filepaths 
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'@AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));

vals = cell(0);
temp_p_iti = [];
temp_pnp_iti = [];

for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);


    CENTER_POINT = [585, 294]; % x and y
    
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
    ts = TimeStamps - expStat.startTS;
    if abs(ts(1)) > 1000 % larger than 1ms
        error("Tracking data's time doesn't match");
    end
    
    %% Recover tracking data
    tracking = [x', y'];
    invalid = tracking(:,1) < 210;
    tracking(invalid, :) = NaN;
    tracking = fillmissing(tracking, 'linear', 1, 'EndValues', 'nearest');
    
    %% Draw All tracking result
    fig = figure();
    plot(tracking(:,1), tracking(:,2), 'k-', 'LineWidth', 0.5);
    hold on;
    plot(CENTER_POINT(1), CENTER_POINT(2), 'r+', 'MarkerSize', 10, 'LineWidth', 1.5);
    axis equal;
    title(sprintf('Tracking: %s', tankName), 'Interpreter', 'none');
    hold off;

    saveas(fig, tankName+".png");

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")







