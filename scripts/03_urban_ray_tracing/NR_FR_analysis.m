%% Urban Link and Coverage Analysis Using Ray Tracing
clear; clc; close all;
 
%% Import and Visualize buildings Data
viewer = siteviewer(Buildings="_seongnam_map.osm", Basemap="topographic");

%% Directional Antenna Setup
% FR1 (4.7 GHz) - 8x8 Antenna Array
lambda_FR1 = physconst('LightSpeed') / 4.7e9;
gNBElement_FR1 = phased.NRAntennaElement('PolarizationAngle', -45, 'Beamwidth', 65);
bsArray_FR1 = phased.NRRectangularPanelArray('Size', [8 8 1 1], ...
    'ElementSet', {gNBElement_FR1}, 'Spacing', lambda_FR1*[0.5 0.5 1 1]);

% FR2 (28 GHz) - 16x16 Antenna Array
lambda_FR2 = physconst('LightSpeed') / 28e9;
gNBElement_FR2 = phased.NRAntennaElement('PolarizationAngle', -45, 'Beamwidth', 30);
bsArray_FR2 = phased.NRRectangularPanelArray('Size', [16 16 1 1], ...
    'ElementSet', {gNBElement_FR2}, 'Spacing', lambda_FR2*[0.5 0.5 1 1]);

%% Define Transmitter Sites
% Gachon University - AI building
tx1 = txsite(Name="Small cell transmitter A (LoS)", ...
    Latitude=37.455715, ...
    Longitude=127.133562, ...
    AntennaHeight=30, ...
    TransmitterPower=2, ...
    TransmitterFrequency=28e9, ...
    Antenna=bsArray_FR2);

% Seoul Airport
tx2 = txsite(Name="Small cell transmitter B (NLoS)", ...
    Latitude=37.4451, ...
    Longitude=127.1106, ...
    AntennaHeight=30, ...
    TransmitterPower=2, ...
    TransmitterFrequency=28e9, ...
    Antenna=bsArray_FR2);

show(tx1); 
show(tx2);

%% Ray Tracing Propagation Model
rtpm = propagationModel("raytracing", ...
    Method="sbr", ...
    MaxNumReflections=3, ...
    MaxNumDiffractions=1, ...
    BuildingsMaterial="concrete", ...
    TerrainMaterial="concrete");

%% Noise Floor Calculation
boltzmann = physconst('Boltzmann');
T = 290; 
NF = 9;  
BW_FR1 = 100e6;
BW_FR2 = 400e6; 
noise_floor_FR1 = 10*log10(boltzmann * T * BW_FR1 * 1000) + NF;
noise_floor_FR2 = 10*log10(boltzmann * T * BW_FR2 * 1000) + NF; 

fprintf('Noise Floor (FR1, 100MHz): %.2f dBm\n', noise_floor_FR1);
fprintf('Noise Floor (FR2, 400MHz): %.2f dBm\n', noise_floor_FR2);

%% UE Placement at Regular Intervals
distance_intervals = [50, 100, 150, 200, 250]; % meters
num_distances = length(distance_intervals);

% TX1 기준 동쪽 방향으로 UE 배치
tx1_lat = 37.455715;
tx1_lon = 127.133562;

rx1_array = cell(1, num_distances);
for idx = 1:num_distances
    dist = distance_intervals(idx);
    lon_offset = dist / 88000;
    
    rx1_array{idx} = rxsite(Name=sprintf("TX1-UE%d", idx), ...
        Latitude=tx1_lat, ...
        Longitude=tx1_lon + lon_offset, ...
        AntennaHeight=1.5);
    show(rx1_array{idx});
end

% TX2 기준 동쪽 방향으로 UE 배치
tx2_lat = 37.4451;
tx2_lon = 127.1106;

rx2_array = cell(1, num_distances);
for idx = 1:num_distances
    dist = distance_intervals(idx);
    lon_offset = dist / 88000;
    
    rx2_array{idx} = rxsite(Name=sprintf("TX2-UE%d", idx), ...
        Latitude=tx2_lat, ...
        Longitude=tx2_lon + lon_offset, ...
        AntennaHeight=1.5);
    show(rx2_array{idx});
end

%% Distance-SINR Analysis for FR1 and FR2 (Fixed 3D Steering)
fprintf('\n=== Distance vs SINR Analysis (3D Steering Applied) ===\n');

% 실제 거리 측정
actual_dist_tx1 = zeros(1, num_distances);
actual_dist_tx2 = zeros(1, num_distances);
for idx = 1:num_distances
    actual_dist_tx1(idx) = distance(tx1, rx1_array{idx}, 'euclidean');
    actual_dist_tx2(idx) = distance(tx2, rx2_array{idx}, 'euclidean');
end

% === TX1 Analysis ===
fprintf('\n[TX1 Analysis]\n');
% FR1 Configuration
tx1_FR1 = txsite(Name="TX1 FR1", Latitude=tx1_lat, Longitude=tx1_lon, ...
    AntennaHeight=30, TransmitterPower=60, TransmitterFrequency=4.7e9, Antenna=bsArray_FR1);
% FR2 Configuration
tx1_FR2 = txsite(Name="TX1 FR2", Latitude=tx1_lat, Longitude=tx1_lon, ...
    AntennaHeight=30, TransmitterPower=2, TransmitterFrequency=28e9, Antenna=bsArray_FR2);

sinr_tx1_FR1 = zeros(1, num_distances);
sinr_tx1_FR2 = zeros(1, num_distances);

for idx = 1:num_distances
    rx = rx1_array{idx};
    
    % [수정] FR1 3D 빔 조향 (Azimuth + Elevation)
    [az_fr1, el_fr1] = angle(tx1_FR1, rx);
    tx1_FR1.AntennaAngle = [az_fr1, el_fr1]; % 수직 방향까지 조절
    rsrp_FR1 = sigstrength(rx, tx1_FR1, rtpm);
    sinr_tx1_FR1(idx) = rsrp_FR1 - noise_floor_FR1;
    
    % [수정] FR2 3D 빔 조향 (Azimuth + Elevation)
    [az_fr2, el_fr2] = angle(tx1_FR2, rx);
    tx1_FR2.AntennaAngle = [az_fr2, el_fr2]; % 수직 방향까지 조절
    rsrp_FR2 = sigstrength(rx, tx1_FR2, rtpm);
    sinr_tx1_FR2(idx) = rsrp_FR2 - noise_floor_FR2;
    
    fprintf('Dist: %5.1fm | FR1 SINR: %5.1f dB | FR2 SINR: %5.1f dB (El: %.1f deg)\n', ...
        actual_dist_tx1(idx), sinr_tx1_FR1(idx), sinr_tx1_FR2(idx), el_fr2);
end

% === TX2 Analysis ===
fprintf('\n[TX2 Analysis]\n');
% FR1 Configuration
tx2_FR1 = txsite(Name="TX2 FR1", Latitude=tx2_lat, Longitude=tx2_lon, ...
    AntennaHeight=30, TransmitterPower=60, TransmitterFrequency=4.7e9, Antenna=bsArray_FR1);
% FR2 Configuration
tx2_FR2 = txsite(Name="TX2 FR2", Latitude=tx2_lat, Longitude=tx2_lon, ...
    AntennaHeight=30, TransmitterPower=2, TransmitterFrequency=28e9, Antenna=bsArray_FR2);

sinr_tx2_FR1 = zeros(1, num_distances);
sinr_tx2_FR2 = zeros(1, num_distances);

for idx = 1:num_distances
    rx = rx2_array{idx};
    
    % [수정] FR1 3D 빔 조향
    [az_fr1, el_fr1] = angle(tx2_FR1, rx);
    tx2_FR1.AntennaAngle = [az_fr1, el_fr1];
    rsrp_FR1 = sigstrength(rx, tx2_FR1, rtpm);
    sinr_tx2_FR1(idx) = rsrp_FR1 - noise_floor_FR1;
    
    % [수정] FR2 3D 빔 조향
    [az_fr2, el_fr2] = angle(tx2_FR2, rx);
    tx2_FR2.AntennaAngle = [az_fr2, el_fr2];
    rsrp_FR2 = sigstrength(rx, tx2_FR2, rtpm);
    sinr_tx2_FR2(idx) = rsrp_FR2 - noise_floor_FR2;
    
    fprintf('Dist: %5.1fm | FR1 SINR: %5.1f dB | FR2 SINR: %5.1f dB (El: %.1f deg)\n', ...
        actual_dist_tx2(idx), sinr_tx2_FR1(idx), sinr_tx2_FR2(idx), el_fr2);
end

%% Distance vs SINR Line Graph
figure('Name', 'Distance vs SINR Comparison', 'Position', [100, 100, 1200, 500]);

% Subplot 1: TX1 Results
subplot(1, 2, 1);
hold on; grid on;
plot(actual_dist_tx1, sinr_tx1_FR1, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR1 (4.7GHz, 60W)');
plot(actual_dist_tx1, sinr_tx1_FR2, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR2 (28GHz, 2W)');
yline(0, 'k--', 'LineWidth', 1.5, 'DisplayName', 'SINR = 0dB');
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('SINR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('TX1 (Gachon Univ) - Distance vs SINR', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, max(actual_dist_tx1)+20]);
hold off;

% Subplot 2: TX2 Results
subplot(1, 2, 2);
hold on; grid on;
plot(actual_dist_tx2, sinr_tx2_FR1, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR1 (4.7GHz, 60W)');
plot(actual_dist_tx2, sinr_tx2_FR2, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR2 (28GHz, 2W)');
yline(0, 'k--', 'LineWidth', 1.5, 'DisplayName', 'SINR = 0dB');
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('SINR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('TX2 (Seoul Airport) - Distance vs SINR', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, max(actual_dist_tx2)+20]);
hold off;

%% Coverage Map Generation
fprintf('\n=== Generating Coverage Maps ===\n');

viz_threshold = -100;
rtpm.MaxNumReflections = 1;

% TX1 Coverage
fprintf('TX1 Coverage...\n');
tx1.AntennaAngle = angle(tx1, rx1_array{3}); % 중간 거리 UE 방향
clearMap(viewer); 

coverage(tx1, rtpm, ...
    SignalStrengths = viz_threshold : -40, ...
    MaxRange = 300, ...
    Resolution = 3, ... 
    Transparency = 0.6, ...
    Colormap = 'jet');

pause(3);

% TX2 Coverage
fprintf('TX2 Coverage...\n');
tx2.AntennaAngle = angle(tx2, rx2_array{3});

coverage(tx2, rtpm, ...
    SignalStrengths = viz_threshold : -40, ...
    MaxRange = 300, ...
    Resolution = 3, ...
    Transparency = 0.6, ...
    Colormap = 'jet');

%% FR1 vs FR2 Difference Map Analysis
fprintf('\n=== FR1 vs FR2 Difference Map ===\n');

center_lat = 37.455715;
center_lon = 127.133562;
range_m = 300;
resolution_m = 10;

[lat_grid, lon_grid] = meshgrid(...
    center_lat - (range_m/111000) : (resolution_m/111000) : center_lat + (range_m/111000), ...
    center_lon - (range_m/88000)  : (resolution_m/88000)  : center_lon + (range_m/88000));

rx_grid = rxsite(Latitude=lat_grid(:), Longitude=lon_grid(:), AntennaHeight=1.5);

% FR1 Transmitter
tx1_FR1_grid = txsite(Name="Tx1 FR1", ...
    Latitude=center_lat, Longitude=center_lon, AntennaHeight=30, ...
    TransmitterPower=60, TransmitterFrequency=4.7e9, Antenna=bsArray_FR1);
tx1_FR1_grid.AntennaAngle = angle(tx1_FR1_grid, rx1_array{3});

% FR2 Transmitter
tx1_FR2_grid = txsite(Name="Tx1 FR2", ...
    Latitude=center_lat, Longitude=center_lon, AntennaHeight=30, ...
    TransmitterPower=2, TransmitterFrequency=28e9, Antenna=bsArray_FR2);
tx1_FR2_grid.AntennaAngle = angle(tx1_FR2_grid, rx1_array{3}); 

% Signal Strength Calculation
fprintf('Simulating FR1...\n');
ss_FR1 = sigstrength(rx_grid, tx1_FR1_grid, rtpm);

fprintf('Simulating FR2...\n');
ss_FR2 = sigstrength(rx_grid, tx1_FR2_grid, rtpm);

% Data Processing
min_val = -120;
ss_FR1(isnan(ss_FR1)) = min_val;
ss_FR2(isnan(ss_FR2)) = min_val;

ss_diff = ss_FR1 - ss_FR2;
ss_diff_matrix = reshape(ss_diff, size(lat_grid));

% Visualization
figure('Name', 'FR1 vs FR2 Performance Difference');
imagesc(ss_diff_matrix);
colorbar;
colormap('jet');
caxis([0 50]);
title(sprintf('RSRP Difference Map (FR1 - FR2)\n@ Gachon Univ (Tx1)'));
xlabel('Grid Index (Longitude)');
ylabel('Grid Index (Latitude)');
axis xy;

fprintf('Mean Difference: %.2f dB\n', mean(ss_diff));
fprintf('Max Difference: %.2f dB\n', max(ss_diff));

fprintf('\n=== Analysis Complete ===\n');