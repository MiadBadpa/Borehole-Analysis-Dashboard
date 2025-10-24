%% Advanced Borehole Analysis and Visualization Dashboard (Version 4.2)
% =========================================================================
% This script provides a comprehensive suite for borehole data visualization.
% v4.2 Feature: Added dynamic plotting for any number of categorical logs,
% with support for image patterns for specific geological logs.
% User can now define all desired categorical logs in the config section.
% =========================================================================

clear; clc; close all;

%% SECTION 0: User Configuration
% =========================================================================
% --- Data File Settings
excelFileName = 'BH181.xlsx'; % Renamed fileName to excelFileName
headerRows = 1; % As per your Excel file, headers are effectively in row 1

% --- Interactive Photo Selection Mode
% Changed to select a folder of photos, not individual photos
interactivePhotoSelect = true;

% --- Columns for Visualization
% Add the names of any categorical columns from your Excel file here.
% Ensure these names exactly match the headers in your Excel file (e.g., 'Rock_Type')
categoricalLogColumns = {'Rock_Type', 'Alteration', 'Texture', 'Minerals'};
% Define the numerical columns you want to plot.
numericColumns = {'Au', 'CuL', 'CuT'};

% --- Manual (Hardcoded) Photo Mapping (used if interactivePhotoSelect is false)
% This section is less relevant now as interactivePhotoSelect is set to true by default
% but kept for backward compatibility if you change interactivePhotoSelect to false.
manualCoreBoxMapping = {
    0,   15,  'IMG_20250419_104609.jpg', []; % Example: {start_depth, end_depth, 'image_filename.jpg', [crop_rect_x y w h]}
};

% --- Pattern Loading Configuration ---
% Define which categorical logs should attempt to use image patterns
patternTargetLogColumns = {'Rock_Type', 'Alteration', 'Texture', 'Minerals'};
MAX_PATTERN_HEIGHT = 100; % pixels - for resizing patterns to improve rendering speed

% --- Interactive Pattern Folder Selection ---
patternFolderPath = ''; % Initialize empty
if isempty(patternFolderPath) || ~isfolder(patternFolderPath)
    patternFolderPath = uigetdir('', 'Select the Folder Containing Geological Patterns (e.g., Granite.png)');
    if isequal(patternFolderPath, 0)
        disp('User canceled pattern folder selection. Patterns will not be used.');
        patternFolderPath = ''; % Ensure it's empty if canceled
    end
end

% --- Pre-load patterns (Optimization) ---
% This map will store loaded image patterns to avoid re-reading them.
% Key: 'CategoryName', Value: struct with fields 'image' (resized double) and 'aspectRatio'
loadedPatterns = containers.Map();


%% SECTION 1: Core Photo Mapping (Automated from Folder and Filename)
% =========================================================================
fprintf('--- CORE PHOTO MAPPING ---\n');
coreBoxMapping = {};

if interactivePhotoSelect
    photoFolderPath = uigetdir('', 'Select the Folder Containing Core Box Images (e.g., 0-7.5.jpg)');
    if isequal(photoFolderPath, 0)
        disp('User canceled photo folder selection. No core photos will be displayed.');
        interactivePhotoSelect = false; % Disable photo plotting if folder not selected
    else
        imageFiles = dir(fullfile(photoFolderPath, '*.jpg'));
        imageFiles = [imageFiles; dir(fullfile(photoFolderPath, '*.png'))];
        imageFiles = [imageFiles; dir(fullfile(photoFolderPath, '*.tif'))];

        if isempty(imageFiles)
            warning('No image files found in the selected folder: %s', photoFolderPath);
            interactivePhotoSelect = false; % Disable photo plotting if no images
        else
            fprintf('Processing %d images from %s...\n', length(imageFiles), photoFolderPath);
            for i = 1:length(imageFiles)
                currentImageFileName = imageFiles(i).name; % Use a local variable for image file name
                fullImagePath = fullfile(photoFolderPath, currentImageFileName);

                % Extract depths from filename (e.g., "0-7.5.jpg")
                [~, name, ~] = fileparts(currentImageFileName); % Use currentImageFileName here
                depthParts = strsplit(name, '-');
                if length(depthParts) == 2
                    try
                        start_depth = str2double(depthParts{1});
                        end_depth = str2double(depthParts{2});

                        if ~isnan(start_depth) && ~isnan(end_depth) && start_depth < end_depth
                            % Crop rectangle is now always empty as we use the full image based on filename
                            coreBoxMapping = [coreBoxMapping; {start_depth, end_depth, fullImagePath, []}];
                        else
                            warning('Invalid depth format in filename: %s. Skipping image.', currentImageFileName);
                        end
                    catch
                        warning('Could not parse depths from filename: %s. Skipping image.', currentImageFileName);
                    end
                else
                    warning('Filename does not follow "start-end.ext" format: %s. Skipping image.', currentImageFileName);
                end
            end
            % Sort coreBoxMapping by start_depth to ensure correct plotting order
            if ~isempty(coreBoxMapping)
                [~, sortedIdx] = sort([coreBoxMapping{:, 1}]);
                coreBoxMapping = coreBoxMapping(sortedIdx, :);
            end
            fprintf('--- PHOTO MAPPING COMPLETE ---\n');
        end
    end
else
    fprintf('Using hardcoded photo mapping.\n');
    photoFolderPath = './Core_Photos/'; % Ensure this folder exists and contains your images
    for i = 1:size(manualCoreBoxMapping, 1), manualCoreBoxMapping{i, 3} = fullfile(photoFolderPath, manualCoreBoxMapping{i, 3}); end
    coreBoxMapping = manualCoreBoxMapping;
end


%% SECTION 2: Data Loading and Preparation
% =========================================================================
fprintf('1. Loading data from: %s\n', excelFileName);
try
    % Use detectImportOptions to correctly identify headers and data
    opts = detectImportOptions(excelFileName);
    
    % --- CRITICAL FIX FOR HEADER READING ---
    % Explicitly set the row where variable names (headers) are.
    % Based on your screenshot, they are in row 1 (A1:S1)
    opts.VariableNamesRange = 'A1:S1'; % Or '1:1' if you prefer. A1:S1 is more explicit.
    % Set data range to start from row 2 (where data actually begins)
    opts.DataRange = 'A2'; 
    
    % If you want MATLAB to generate valid names from your headers
    opts.VariableNamingRule = 'modify'; 
    % --- END CRITICAL FIX ---

    data = readtable(excelFileName, opts);

    % --- DEBUGGING STEP (KEEP THIS FOR NOW TO VERIFY) ---
    fprintf('DEBUG: Variable names as read by MATLAB AFTER explicit range setting:\n');
    disp(data.Properties.VariableNames);
    fprintf('--------------------------------------\n');
    % --- END DEBUGGING STEP ---

    % --- Simplified Column Name Cleaning (should be less needed now but good for robustness) ---
    % This part can be simplified because VariableNamesRange and VariableNamingRule should do most work.
    % However, trimming can still be useful.
    currentVarNames = data.Properties.VariableNames;
    newVarNames = cell(size(currentVarNames));
    for i = 1:length(currentVarNames)
        newVarNames{i} = strtrim(currentVarNames{i}); % Just trim spaces
    end
    data.Properties.VariableNames = newVarNames;
    % --- END Simplified ---

    % Verify critical columns exist after cleaning names
    requiredColumns = [{'From', 'To'}, categoricalLogColumns, numericColumns];
    missingCols = setdiff(requiredColumns, data.Properties.VariableNames);
    if ~isempty(missingCols)
        error('The following required columns were not found or could not be mapped in the Excel file: %s. Please check your Excel header names or config. Current detected headers: %s', strjoin(missingCols, ', '), strjoin(data.Properties.VariableNames, ', '));
    end

    % Combine all numeric columns (including 'From' and 'To') to check for numeric conversion
    allNumCols = [numericColumns, {'From', 'To'}];
    for i = 1:length(allNumCols)
        colName = allNumCols{i}; % Use the cleaned column name
        % Attempt to convert to double if it's not already numeric.
        if ~isnumeric(data.(colName))
            if iscell(data.(colName))
                data.(colName) = str2double(data.(colName));
            elseif isstring(data.(colName))
                data.(colName) = str2double(data.(colName));
            end
        end
        % Handle NaN values resulting from conversion errors by setting them to 0 or another suitable default
        if any(isnan(data.(colName)))
            warning('NaN values found in numeric column "%s" after conversion. These will be treated as missing or zero.', colName);
            % Optionally, you could replace NaNs: data.(colName)(isnan(data.(colName))) = 0;
        end
    end

    % Ensure 'From' and 'To' are valid and 'From' < 'To'
    if any(data.From >= data.To)
        warning('Some ''From'' depths are greater than or equal to ''To'' depths. This might lead to incorrect plotting. Please check your "From" and "To" data for consistency.');
    end

catch ME, error('Data loading or initial processing error: \n%s', ME.message); end


%% SECTION 3: 2D Composite Log Visualization
% =========================================================================
fprintf('2. Creating 2D composite log...\n');

% --- Dynamic Layout Calculation ---
numPhotoPlots = 1;
numCategoricalPlots = length(categoricalLogColumns);
numNumericPlots = length(numericColumns);

% Calculate total columns for tiled layout. We add 1 because the photo plot will span 2 "slots".
totalLayoutColumns = numPhotoPlots + numCategoricalPlots + numNumericPlots + 1;

mainFig = figure('Name', ['2D Composite Log: ' excelFileName], 'NumberTitle', 'off', 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.8]);
t = tiledlayout(1, totalLayoutColumns, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel 1: Core Photos ---
ax1 = nexttile([1 2]); % This makes ax1 span 1 row and 2 columns
hold(ax1, 'on');
title('Core Photos');
if ~isempty(coreBoxMapping)
    for i = 1:size(coreBoxMapping, 1)
        start_depth = coreBoxMapping{i, 1};
        end_depth = coreBoxMapping{i, 2};
        img_path = coreBoxMapping{i, 3};
        crop_rect = coreBoxMapping{i, 4}; % Will be empty now

        if isfile(img_path)
            try
                img = imread(img_path);
                % Based on your description ("بالای تصویر من همان عمق کمتر است در اینجا صفر متر و زیر تصویر من قسمت عمیق تر است یعنی اینجا 6.7 متر است.")
                % and wanting Y-axis to go from 0 (top) to Max (bottom),
                % we should display the image as is (without flipud) because its inherent orientation
                % matches the desired 'reverse' YDir for the plot.
                imagesc(ax1, [0 1], [start_depth end_depth], img);
                
            catch ME_img
                warning('Could not load or process image "%s". Displaying placeholder. Error: %s', img_path, ME_img.message);
                % Display a placeholder if image loading fails
                patch(ax1, [0 1 1 0], [start_depth start_depth end_depth end_depth], [0.8 0.8 0.8], 'EdgeColor', 'r');
                text(ax1, 0.5, (start_depth + end_depth)/2, 'Image Error', 'Horiz', 'center', 'Color', 'k');
            end
        else
            warning('Image file not found: %s', img_path);
            patch(ax1, [0 1 1 0], [start_depth start_depth end_depth end_depth], [0.8 0.8 0.8], 'EdgeColor', 'r');
            text(ax1, 0.5, (start_depth + end_depth)/2, 'File Missing', 'Horiz', 'center', 'Color', 'k');
        end
    end
end
% --- FIX for Problem 2: Set YDir to 'reverse' for "depth-down" display on all plots ---
set(ax1, 'YDir', 'reverse'); 
ylabel('Depth (m)');
% --- FIX for Problem 2: Set Y-axis limits and ticks for "depth-down" display ---
% The ylim values should still be increasing: [min_val max_val]
% 'reverse' YDir will make the plot appear with max_val at bottom.
ylim(ax1, [0 max(data.To)]); % Corrected: min_value 0, max_value max(data.To)
% Set Y-ticks for depth (e.g., every 10m)
yTicks = 0:10:max(data.To); 
set(ax1, 'YTick', yTicks, 'YTickLabel', string(yTicks)); 
set(ax1, 'XTick', []); % No X-ticks for image panel
box(ax1, 'on'); % Add a box around the plot


% --- Panels for Geological Logs (Dynamic plotting for categorical logs - MODIFIED FOR PATTERNS & LABELING) ---
logAxes = [];
colorMaps = {@jet, @cool, @parula, @hsv, @spring, @autumn, @winter, @gray};
for i = 1:numCategoricalPlots
    ax = nexttile;
    logAxes(i) = ax;
    hold on;
    colName = categoricalLogColumns{i}; % Current categorical column to plot

    % Check if column exists in the data table
    % Now using the cleaned variable names
    if ~ismember(colName, data.Properties.VariableNames)
        warning('Column "%s" not found in the data file after name cleaning. Skipping this plot.', colName);
        title(['Error: ' strrep(colName, '_', ' ') ' Not Found']);
        set(gca, 'XTick', []);
        continue;
    end

    % Use data relevant to the current categorical column, removing NaNs from From/To/colName
    plotDataLog = data(~any(ismissing(data(:, {'From', 'To', colName})), 2), :);

    % Add an explicit check if plotDataLog is empty after rmmissing
    if isempty(plotDataLog)
        warning('No valid data found for column "%s" after removing missing values. Skipping plot.', colName);
        title(['No Data for ' strrep(colName, '_', ' ')]);
        set(gca, 'XTick', []);
        continue; % Skip to the next categorical log
    end

    % Convert categorical data to cell strings (important for unique and map keys)
    % Handles: string array, categorical array, char array in cell
    if isstring(plotDataLog.(colName))
        plotDataLog.(colName) = cellstr(plotDataLog.(colName));
    elseif iscategorical(plotDataLog.(colName))
        plotDataLog.(colName) = cellstr(plotDataLog.(colName));
    elseif iscell(plotDataLog.(colName)) && ~iscellstr(plotDataLog.(colName)) % If cell but not cellstr
        plotDataLog.(colName) = cellfun(@(x) char(string(x)), plotDataLog.(colName), 'UniformOutput', false); % Convert elements to char, then cellstr
    end

    categories = unique(plotDataLog.(colName));

    % If there are no categories (e.g., all values were empty or NaN), skip plotting
    if isempty(categories)
        warning('No unique categories found for column "%s". Skipping plot.', colName);
        title(['No Categories for ' strrep(colName, '_', ' ')]);
        set(gca, 'XTick', []);
        continue;
    end

    % --- Pattern vs. Solid Color Logic ---
    use_pattern_for_this_log = ismember(colName, patternTargetLogColumns) && ~isempty(patternFolderPath);

    % Initialize colormap for solid colors if patterns are not used or fail
    currentColormapFunc = colorMaps{mod(i-1, length(colorMaps)) + 1};
    solid_colors = currentColormapFunc(max(1, numel(categories)));
    solid_colorMap = containers.Map(categories, mat2cell(solid_colors, ones(numel(categories), 1), 3));

    % --- Loop through data, identify blocks of identical categories ---
    k = 1; % Current index in plotDataLog
    while k <= height(plotDataLog)
        current_cat_val_cell = plotDataLog.(colName){k};
        current_cat_val_str = string(current_cat_val_cell);

        block_start_depth = plotDataLog.From(k);
        block_end_depth = plotDataLog.To(k);

        % Find end of current block
        next_k = k + 1;
        while next_k <= height(plotDataLog) && ...
                strcmp(plotDataLog.(colName){next_k}, current_cat_val_cell) && ...
                plotDataLog.From(next_k) == block_end_depth % Check for continuous depth
            block_end_depth = plotDataLog.To(next_k);
            next_k = next_k + 1;
        end

        % Plotting the block
        pattern_drawn = false;
        if use_pattern_for_this_log && ~ismissing(current_cat_val_str) && current_cat_val_str ~= "" && current_cat_val_str ~= "Undefined"
            % Check if pattern is already loaded
            if isKey(loadedPatterns, char(current_cat_val_str))
                pattern_info = loadedPatterns(char(current_cat_val_str));
                P_resized_double = pattern_info.image;
                one_tile_H_data_units = pattern_info.aspectRatio;
                pattern_drawn = true;
            else
                % Attempt to load pattern
                pattern_base_name = char(current_cat_val_str);
                pattern_full_path = '';
                extensions = {'.png', '.jpg', '.jpeg', '.tif', '.bmp'};
                for ext_idx = 1:length(extensions)
                    temp_path = fullfile(patternFolderPath, [pattern_base_name extensions{ext_idx}]);
                    if isfile(temp_path), pattern_full_path = temp_path; break; end
                end

                if ~isempty(pattern_full_path)
                    try
                        P_orig = imread(pattern_full_path);
                        P_rgb = [];
                        [~, ~, pD_orig] = size(P_orig);
                        if pD_orig == 3, P_rgb = P_orig;
                        elseif pD_orig == 1, P_rgb = cat(3, P_orig, P_orig, P_orig);
                        else
                            [img_indexed, map] = imread(pattern_full_path);
                            if ~isempty(map) && (ismatrix(img_indexed) || size(img_indexed,3) == 1)
                                P_rgb = ind2rgb(img_indexed, map);
                            elseif pD_orig == 4, P_rgb = P_orig(:,:,1:3);
                            end
                        end

                        if ~isempty(P_rgb)
                            [pH_orig, pW_orig, ~] = size(P_rgb);
                            if pW_orig == 0, error('Original pattern has zero width.'); end

                            if pH_orig > MAX_PATTERN_HEIGHT
                                P_resized = imresize(P_rgb, [MAX_PATTERN_HEIGHT, NaN]);
                            else
                                P_resized = P_rgb;
                            end
                            P_resized_double = im2double(P_resized);

                            [pH_resized, pW_resized, ~] = size(P_resized_double);
                            if pW_resized == 0, error('Resized pattern has zero width.'); end

                            one_tile_H_data_units = (pH_resized / pW_resized) * 1.0;
                            if one_tile_H_data_units <= 1e-6, error('Pattern aspect ratio is invalid (too small).'); end

                            loadedPatterns(char(current_cat_val_str)) = struct('image', P_resized_double, 'aspectRatio', one_tile_H_data_units);
                            pattern_drawn = true;
                        end
                    catch ME_pattern
                        fprintf('Warning: Failed to load/process pattern "%s" for category "%s": %s. Using solid color.\n', pattern_full_path, current_cat_val_str, ME_pattern.message);
                        pattern_drawn = false;
                    end
                end
            end
        end

        % Draw pattern or solid color for the entire block
        if pattern_drawn
            y_curr_tile_start = block_start_depth;
            while y_curr_tile_start < block_end_depth
                y_curr_tile_end = y_curr_tile_start + one_tile_H_data_units;
                draw_segment_y_start = y_curr_tile_start;
                draw_segment_y_end = min(y_curr_tile_end, block_end_depth);

                if (draw_segment_y_end - draw_segment_y_start) <= 1e-6; break; end

                % --- FIX: No flipud needed here for patterns, assuming they are oriented top-down ---
                imagesc(ax, [0 1], [draw_segment_y_start, draw_segment_y_end], P_resized_double);
                
                y_curr_tile_start = draw_segment_y_end;
            end
        else % Use solid color
            if isKey(solid_colorMap, char(current_cat_val_str))
                patch_color = solid_colorMap(char(current_cat_val_str));
            else
                patch_color = [0.5 0.5 0.5];
            end
            patch([0 1 1 0], [block_start_depth block_start_depth block_end_depth block_end_depth], ...
                    patch_color, 'EdgeColor', 'k');
        end

        % --- Text Labeling (MODIFIED for single label per block) ---
        % Only draw label if block is tall enough and value is not empty/undefined
        if (block_end_depth - block_start_depth) > 0.2 && ... % Minimum height for label visibility
           strlength(current_cat_val_str) > 0 && ~ismissing(current_cat_val_str) && current_cat_val_str ~= "Undefined"
            text(0.5, (block_start_depth + block_end_depth)/2, strrep(char(current_cat_val_str), '_', ' '), ...
                'Rotation', 0, 'HorizontalAlignment','center','VerticalAlignment','middle',...
                'FontSize', 8, 'FontWeight', 'bold', ...
                'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 1);
        end

        k = next_k; % Move to the start of the next block
    end % End of while loop for blocks

    % --- FIX for Problem 2: Set YDir to 'reverse' for "depth-down" display ---
    set(ax, 'YDir', 'reverse'); 
    % --- FIX for Problem 2: Set Y-axis limits and ticks for "depth-down" display ---
    ylim(ax, [0 max(data.To)]); % Corrected: min_value 0, max_value max(data.To)
    set(ax, 'XTick', [], 'YTickLabel', []);
    title(strrep(colName, '_', ' '));
    box(ax, 'on');
end

% --- Panels for Numerical Logs ---
numericAxes = [];
plotColors = {'b', 'r', 'g', 'm', 'c', 'k', [0.85 0.33 0.1], [0.93 0.69 0.13]};
for i = 1:numNumericPlots
    ax = nexttile;
    numericAxes(i) = ax;
    hold on;
    colName = numericColumns{i};

    % Check if column exists in the data table (using cleaned names)
    if ~ismember(colName, data.Properties.VariableNames)
        warning('Numeric column "%s" not found in the data file after name cleaning. Skipping this plot.', colName);
        title(['Error: ' strrep(colName, '_', ' ') ' Not Found']);
        set(gca, 'XTick', []);
        continue;
    end

    % --- FIX: Plot numerical data against the 'From' depth for correct display with reversed Y-axis ---
    plot(data.(colName), data.From, '-o', 'Color', plotColors{mod(i-1, length(plotColors)) + 1}, ...
         'MarkerFaceColor', plotColors{mod(i-1, length(plotColors)) + 1}, 'MarkerSize', 4);
    title(strrep(colName, '_', ' '));
    xlabel('Value');
    grid on;
    box(ax, 'on');
end

% --- Link Axes and Final Adjustments ---
allAxes = [ax1, logAxes, numericAxes];
linkaxes(allAxes, 'y');
% --- FIX: Set YTickLabel for linked axes to reflect depth-down ---
set(allAxes(2:end), 'YTickLabel', []); % Only ax1 will have labels, others will be linked
% --- FIX: Set Y-axis limits for all linked axes ---
ylim(allAxes, [0 max(data.To)]); % Corrected: min_value 0, max_value max(data.To)
fprintf('Visualization rendering complete.\n');


%% SECTION 3.5: Interactive Annotation Mode
% =========================================================================
fprintf('3. Entering Interactive Annotation mode...\n');
savedAnnotations = struct('Position', {}, 'Label', {}, 'LinkedFile', {});
[~, baseName, ~] = fileparts(excelFileName);
outputMatName = sprintf('%s_SessionData.mat', baseName);

if isfile(outputMatName)
    fprintf('    Loading previous annotations from %s\n', outputMatName);
    load(outputMatName, 'savedAnnotations');
    if ~exist('savedAnnotations', 'var') || isempty(savedAnnotations)
        savedAnnotations = struct('Position', {}, 'Label', {}, 'LinkedFile', {});
    end
    redraw_annotations(ax1, savedAnnotations);
end

userAction = '';
while ~strcmp(userAction, 'Finish and Save')
    userAction = questdlg('Manage interactive annotations:', 'Annotation Menu', ...
        'Add/Edit Annotations', 'Clear All and Start Fresh', 'Finish and Save', 'Finish and Save');

    switch userAction
        case 'Add/Edit Annotations'
            addMore = true;
            while addMore
                title(ax1, 'Draw a rectangle for the new annotation (Right-click to finish drawing)', 'FontSize', 12);
                roi = drawrectangle(ax1, 'Color', 'y', 'FaceAlpha', 0.2);

                if isempty(roi.Position)
                    addMore = false;
                    continue;
                end

                labelAnswer = inputdlg('Enter a label for this box (e.g., A):', 'Annotation Label', [1 30]);
                if isempty(labelAnswer) || isempty(labelAnswer{1})
                    roi.delete();
                    continue;
                end

                [file, path] = uigetfile({'*.jpg;*.png;*.gif;*.tif;*.pdf;*.txt', 'Select File (*.jpg, *.png, *.pdf, *.txt)'}, 'Select a file to link');
                if isequal(file, 0)
                    roi.delete();
                    continue;
                end

                newAnnotation.Position = roi.Position;
                newAnnotation.Label = labelAnswer{1};
                newAnnotation.LinkedFile = fullfile(path, file);
                savedAnnotations(end+1) = newAnnotation;
                roi.delete();

                redraw_annotations(ax1, savedAnnotations);

                addChoice = questdlg('Add another annotation?', 'Continue?', 'Yes', 'No', 'Yes');
                if strcmp(addChoice, 'No'), addMore = false; end
            end

        case 'Clear All and Start Fresh'
            confirmClear = questdlg('Are you sure you want to delete all annotations?', 'Confirm Clear', 'Yes', 'No', 'No');
            if strcmp(confirmClear, 'Yes')
                savedAnnotations = struct('Position', {}, 'Label', {}, 'LinkedFile', {});
                redraw_annotations(ax1, savedAnnotations);
                fprintf('    All annotations cleared.\n');
            end

        case 'Finish and Save'
            fprintf('    Annotation process finished by user.\n');

        otherwise
            fprintf('    Annotation process cancelled.\n');
            break;
    end
end
title(ax1, 'Core Photos');

%% SECTION 4: Save Outputs
% =========================================================================
fprintf('4. Saving the output figure...\n');
try
    outputImageName = sprintf('%s_CompositeLog.png', baseName);
    print(mainFig, outputImageName, '-dpng', '-r300');
    fprintf('    Figure saved successfully to: %s\n', fullfile(pwd, outputImageName));
catch ME, warning('Could not save the PNG figure. Error: %s', ME.message); end

fprintf('5. Saving session data and annotations...\n');
try
    save(outputMatName, 'savedAnnotations');
    fprintf('    Session data saved successfully to: %s\n', fullfile(pwd, outputMatName));
catch ME, warning('Could not save the session .mat file. Error: %s', ME.message); end

fprintf('\n*** Script finished successfully. ***\n');


%% LOCAL FUNCTIONS
% =========================================================================
function redraw_annotations(target_axes, annotation_data)
    delete(findobj(target_axes, 'Tag', 'InteractiveAnnotation'));

    if isempty(annotation_data), return; end

    for k = 1:numel(annotation_data)
        pos = annotation_data(k).Position;
        label = annotation_data(k).Label;
        filePath = annotation_data(k).LinkedFile;

        rect = rectangle(target_axes, 'Position', pos, 'EdgeColor', 'r', 'LineWidth', 2, 'Tag', 'InteractiveAnnotation');

        text_label = text(target_axes, pos(1) + pos(3)/2, pos(2) + pos(4)/2, label, ...
            'Color', 'w', 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'Tag', 'InteractiveAnnotation', ...
            'BackgroundColor', [0.8 0 0], 'Margin', 1);

        if isfile(filePath)
            set([rect, text_label], 'ButtonDownFcn', @(s,e) open(filePath));
        else
            set([rect, text_label], 'ButtonDownFcn', @(s,e) warndlg(['Linked file not found: ' filePath], 'File Missing Warning'));
        end
    end
end