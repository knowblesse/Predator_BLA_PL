% Draw_Temporal_Comparison_PreRobot_vs_Robot

% Compare decoding accuracy between Pre-robot and Robot sessions, within region.
% Two output figures (one per region), paired t-tests across the 8 time windows.

%% Inputs
PARENT_PATH_PRE   = 'H:\Data\Kim Data\prerobot_2s';
PARENT_PATH_ROBOT = 'H:\Data\Kim Data\robot_iti_2s_more';

%% Style — colors
COLOR_BLA_PRE   = '#E783B2';   % light pink
COLOR_BLA_ROBOT = '#9F044D';   % saturated red (vivid)
COLOR_PFC_PRE   = '#7AA6A6';   % light teal
COLOR_PFC_ROBOT = '#056943';   % saturated green (vivid)

DRAW_SHADE  = true;
ALPHA_SHADE = 0.25;
LW_MEAN     = 2.5;
DOT_SIZE    = 5;

AXIS_LW     = 1.44;
FONT_NAME   = 'Arial';
FONT_SIZE   = 12;
FONT_WEIGHT = 'normal';

TITLE_SIZE  = 13.92;

STAR_FONT   = 'Arial';
STAR_SIZE   = 14;

% Star row position — fixed near top of plot, in data units
STAR_ROW_Y  = 0.86;

% Sizes
TOTAL_WIDTH_MM   = 130.04;     % includes legend
TOTAL_HEIGHT_MM  = 80.741;
AXES_WIDTH_MM    = 76;
AXES_HEIGHT_MM   = 51;

% Y-axis
Y_LIMITS = [0.4 0.9];
Y_TICKS  = 0.4:0.1:0.9;

%% Time windows (use only first 8; robot file may have more)
TIME_WINDOWS = [-8 -6; -6 -4; -4 -2; -2 0; 0 2; 2 4; 4 6; 6 8];
n_win = size(TIME_WINDOWS, 1);
x = 1:n_win;
xtick_labels = arrayfun(@(i) sprintf('%d', (TIME_WINDOWS(i,2) + TIME_WINDOWS(i,1))/2), ...
                        1:n_win, 'UniformOutput', false);

%% Helper: load and align two CSVs by Session column, return matched matrices
norm_name = @(s) regexprep(s, '[^A-Za-z0-9]', '');

function mat = extract_real_matrix(T, time_windows)
    % Pull "T(t0,t1)_Real" columns in order; handle MATLAB's name mangling.
    n_sess = height(T);
    n_win  = size(time_windows, 1);
    mat = zeros(n_sess, n_win);

    vars = T.Properties.VariableNames;
    norm_name_fn = @(s) regexprep(s, '[^A-Za-z0-9]', '');
    vars_norm = cellfun(norm_name_fn, vars, 'UniformOutput', false);

    for j = 1:n_win
        t0 = time_windows(j,1); t1 = time_windows(j,2);
        target = norm_name_fn(sprintf('T(%d,%d)_Real', t0, t1));
        idx = find(strcmp(vars_norm, target), 1);
        if isempty(idx)
            error('Column for window (%d,%d) not found.', t0, t1);
        end
        mat(:, j) = T.(vars{idx});
    end
end

%% Run the two comparisons (BLA, then PFC)
regions = {'BLA', 'PFC'};
colors_pre   = {COLOR_BLA_PRE,   COLOR_PFC_PRE};
colors_robot = {COLOR_BLA_ROBOT, COLOR_PFC_ROBOT};

for r = 1:length(regions)
    region = regions{r};
    fprintf('\n===== %s =====\n', region);

    pre_csv   = fullfile(PARENT_PATH_PRE,   sprintf('temporal_%s.csv', region));
    robot_csv = fullfile(PARENT_PATH_ROBOT, sprintf('temporal_%s.csv', region));

    pre_T   = readtable(pre_csv);
    robot_T = readtable(robot_csv);

    % Match sessions by name (column "Session")
    pre_sess   = pre_T.Session;
    robot_sess = robot_T.Session;
    common_sess = intersect(pre_sess, robot_sess, 'stable');

    fprintf('Pre-robot sessions: %d, Robot sessions: %d, Common: %d\n', ...
        height(pre_T), height(robot_T), numel(common_sess));
    dropped_pre   = setdiff(pre_sess,   common_sess);
    dropped_robot = setdiff(robot_sess, common_sess);
    if ~isempty(dropped_pre)
        fprintf('Dropped from pre-robot: %s\n', strjoin(dropped_pre, ', '));
    end
    if ~isempty(dropped_robot)
        fprintf('Dropped from robot: %s\n', strjoin(dropped_robot, ', '));
    end

    % Reorder both tables to common_sess order
    [~, idx_pre]   = ismember(common_sess, pre_sess);
    [~, idx_robot] = ismember(common_sess, robot_sess);
    pre_T   = pre_T(idx_pre, :);
    robot_T = robot_T(idx_robot, :);

    % Extract Real-accuracy matrices (sessions x windows)
    pre_real   = extract_real_matrix(pre_T,   TIME_WINDOWS);
    robot_real = extract_real_matrix(robot_T, TIME_WINDOWS);
    n_sess     = numel(common_sess);

    % Per-window paired t-tests with Sidak correction
    p_raw = zeros(1, n_win);
    for j = 1:n_win
        [~, p_raw(j)] = ttest(pre_real(:,j), robot_real(:,j));
    end

    % Sort p-values, apply BH adjustment, then enforce monotonicity
    [p_sorted, sort_idx] = sort(p_raw);
    ranks = 1:n_win;
    p_bh_sorted = p_sorted .* n_win ./ ranks;

    % Enforce monotonicity from largest to smallest
    for k = n_win-1:-1:1
        p_bh_sorted(k) = min(p_bh_sorted(k), p_bh_sorted(k+1));
    end
    % Unsort back to original window order
    p_corr = zeros(1, n_win);
    p_corr(sort_idx) = p_bh_sorted;
    p_corr = min(p_corr, 1);



    STARS = zeros(1, n_win);
    STARS(p_corr < 0.05)  = 1;
    STARS(p_corr < 0.01)  = 2;
    STARS(p_corr < 0.001) = 3;

    fprintf('Window         raw p   Sidak p   stars\n');
    for j = 1:n_win
        fprintf('(%2d,%2d):    %8.4f  %8.4f   %s\n', ...
            TIME_WINDOWS(j,1), TIME_WINDOWS(j,2), ...
            p_raw(j), p_corr(j), repmat('*', 1, STARS(j)));
    end

    %% Plot
    figure;
    clf;
    ax = axes(gcf);
    ax.Color = 'none';
    hold(ax, 'on');

    % Reference line at chance + event marker between windows 4 and 5
    yline(ax, 0.5, ':', 'Color', [0 0 0], 'LineWidth', 0.6, ...
        'Alpha', 0.5, 'HandleVisibility', 'off');
    xline(ax, 4.5, '--', 'Color', 'r', 'HandleVisibility', 'off');

    % Pre-robot trace
    [~, h_pre, ~] = shadeplot(x, pre_real, ...
        'SD', 'sem', 'Color', colors_pre{r}, 'LineStyle', '-', ...
        'LineWidth', LW_MEAN, 'FaceColor', colors_pre{r}, ...
        'FaceAlpha', ALPHA_SHADE * DRAW_SHADE, 'ax', ax);
    plot(ax, x, mean(pre_real, 1), 'o', 'Color', colors_pre{r}, ...
        'MarkerFaceColor', colors_pre{r}, 'MarkerSize', DOT_SIZE, ...
        'HandleVisibility', 'off');

    % Robot trace
    [~, h_robot, ~] = shadeplot(x, robot_real, ...
        'SD', 'sem', 'Color', colors_robot{r}, 'LineStyle', '-', ...
        'LineWidth', LW_MEAN, 'FaceColor', colors_robot{r}, ...
        'FaceAlpha', ALPHA_SHADE * DRAW_SHADE, 'ax', ax);
    plot(ax, x, mean(robot_real, 1), 's', 'Color', colors_robot{r}, ...
        'MarkerFaceColor', colors_robot{r}, 'MarkerSize', DOT_SIZE, ...
        'HandleVisibility', 'off');

    % Significance stars in a fixed row near the top
    for j = 1:n_win
        if STARS(j) > 0
            text(ax, x(j), STAR_ROW_Y, repmat('*', 1, STARS(j)), ...
                'FontName', STAR_FONT, 'FontSize', STAR_SIZE, ...
                'FontWeight', 'bold', 'Color', 'k', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        end
    end

    % Axes formatting
    ax.LineWidth   = AXIS_LW;
    ax.FontName    = FONT_NAME;
    ax.FontSize    = FONT_SIZE;
    ax.FontWeight  = FONT_WEIGHT;
    ax.TickDir     = 'out';
    ax.TickDirMode = 'manual';
    ax.Box = 'off';

    xlabel(ax, 'Time from Event (s)', ...
        'FontName', FONT_NAME, 'FontSize', FONT_SIZE, 'FontWeight', FONT_WEIGHT);
    ylabel(ax, 'Balanced Accuracy', ...
        'FontName', FONT_NAME, 'FontSize', FONT_SIZE, 'FontWeight', FONT_WEIGHT);
    xticks(ax, x);
    xticklabels(ax, xtick_labels);
    xlim(ax, [0.5 n_win+0.5]);
    ylim(ax, Y_LIMITS);
    yticks(ax, Y_TICKS);

    % Title — region label, not the bold formal style
    region_label = region;
    if strcmp(region, 'PFC')
        region_label = 'mPFC';
    end
    title(ax, sprintf('%s', region_label), ...
        'FontName', FONT_NAME, 'FontSize', TITLE_SIZE, 'FontWeight', 'normal');

    % Legend
    legend(ax, [h_pre, h_robot], {'Pre-robot', 'Robot'}, ...
        'Location', 'eastoutside', 'Box', 'off', ...
        'FontName', FONT_NAME, 'FontSize', FONT_SIZE, 'FontWeight', FONT_WEIGHT);

    hold(ax, 'off');

    %% Set figure size
    fig = gcf;
    fig.Units = 'centimeters';
    fig.Position = [fig.Position(1) fig.Position(2) ...
                    TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];
    fig.PaperUnits        = 'centimeters';
    fig.PaperPosition     = [0 0 TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];
    fig.PaperSize         = [TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];
    fig.PaperPositionMode = 'manual';

    ax.Units = 'centimeters';
    left_margin   = 1.4;
    bottom_margin = 1.6;
    ax.Position = [left_margin bottom_margin AXES_WIDTH_MM/10 AXES_HEIGHT_MM/10];

    %% Export
    EXPORT_PATH = fullfile(PARENT_PATH_ROBOT, ...
        sprintf('decoding_compare_%s.svg', region));
    exportgraphics(fig, EXPORT_PATH, 'ContentType', 'vector');
    fprintf('Exported: %s\n', EXPORT_PATH);
end