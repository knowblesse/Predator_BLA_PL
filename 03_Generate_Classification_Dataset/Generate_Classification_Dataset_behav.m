%% Generate_Classification_Dataset
% 2026 Ji Hoon Jeong
% Script for tank batch

%% Set Variables
BASEPATH = "H:\Data\Kim Data";
n = 2;

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

    helperFilePath = fullfile(tankPath, strcat(tankName(2:end), '_helper.mat'));
    load(helperFilePath);

    %Load event file
    eventFilePath = fullfile(tankPath, strcat(tankName(2:end), '_event.mat'));
    load(eventFilePath);
    
    switch n
        case 1
            % 1 : Event1 vs Event2: pre-robot NP vs. post-robot NP Context
            % (NP)
            % PreRobotNP_RobotNP
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]);
            eventTime2 = double([eventData([eventData.Robot] == 1).NP]);
            [X, y] = generateEventClassifierDataset_behav(tankPath, eventTime1, eventTime2);
            save(fullfile(tankPath,"PreRobotNP_RobotNP_behav_speed.mat"), "X", "y");
        case 2
            % 2 : Event1 vs Event2: pre-robot NP vs. pre-robot P
            % (Preference Safe)
            % PreRobotNP_PreRobotP
            eventTime1 = double([eventData([eventData.Robot] == 0).NP]);
            eventTime2 = double([eventData([eventData.Robot] == 0).P]);
            [X, y] = generateEventClassifierDataset_behav(tankPath, eventTime1, eventTime2);
            save(fullfile(tankPath,"PreRobotNP_PreRobotP_behav_speed.mat"), "X", "y");
        
        case 17
            % 17 : Event1 vs Event2: robot NP vs. robot P Preference
            % (Risky)
            % RobotNP_RobotP
            eventTime1 = [];
            eventTime2 = [];

            for i = 1 : size(eventDataRaw,1)
                if ... % Robot session + P 
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "P"
                    eventTime1 = [eventTime1; double(eventDataRaw.Time_ms(i))];
                end

                if ... % Robot session + NP
                        eventDataRaw.Robot(i) == 1 &...
                        eventDataRaw.PelletType(i) == "NP" 
                    eventTime2 = [eventTime2; double(eventDataRaw.Time_ms(i))];
                end
            end
            if numel(eventTime1) < 3 | numel(eventTime2) <3
                fprintf("Skipped due to small event number\n");
                continue;
            end
            [X, y] = generateEventClassifierDataset_behav(tankPath, eventTime1, eventTime2);
            save(fullfile(tankPath,"RobotNP_RobotP_behav_speed.mat"), "X", "y");

        case 19
            % 19 : Event1 vs Event2: pre-robot P vs. robot P  % Context (P)
            % PreRobotP_RobotP
            eventTime1 = double([eventData([eventData.Robot] == 0).P]);
            eventTime2 = []; % Robot session + P 
            
            for i = 1 : size(eventDataRaw,1)
                if eventDataRaw.Robot(i) == 1 & eventDataRaw.PelletType(i) == "P"
                    eventTime2 = [eventTime2; double(eventDataRaw.Time_ms(i))];
                end
            end
            if numel(eventTime2) <3
                fprintf("Skipped due to small event number\n");
                continue;
            end
            [X, y] = generateEventClassifierDataset_behav(tankPath, eventTime1, eventTime2);
            save(fullfile(tankPath,"PreRobotP_RobotP_behav_speed.mat"), "X", "y");
    end

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")