%% Urban Link and Coverage Analysis - Corrected SNR/SINR Calculation
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

% Noise Power (dBm) = 10*log10(k*T*BW*1000) + NF
noise_floor_FR1 = 10*log10(boltzmann * T * BW_FR1 * 1000) + NF;
noise_floor_FR2 = 10*log10(boltzmann * T * BW_FR2 * 1000) + NF; 

fprintf('========================================================\n');
fprintf('           System Configuration\n');
fprintf('========================================================\n');
fprintf('Noise Floor (FR1, 100MHz): %.2f dBm\n', noise_floor_FR1);
fprintf('Noise Floor (FR2, 400MHz): %.2f dBm\n', noise_floor_FR2);
fprintf('========================================================\n');

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

%% Distance-SNR/SINR Analysis
fprintf('\n========================================================\n');
fprintf('    Distance vs SNR/SINR Analysis (Corrected)\n');
fprintf('========================================================\n');

% 실제 거리 계산
actual_dist_tx1 = zeros(1, num_distances);
actual_dist_tx2 = zeros(1, num_distances);
for idx = 1:num_distances
    actual_dist_tx1(idx) = distance(tx1, rx1_array{idx}, 'euclidean');
    actual_dist_tx2(idx) = distance(tx2, rx2_array{idx}, 'euclidean');
end

% 현실적인 최대 SNR 한계 (Hardware/EVM Limit)
MAX_SNR_CAP = 40;  % dB

% === TX1 Analysis ===
fprintf('\n[TX1 Analysis - Gachon University]\n');
fprintf('----------------------------------------------------------\n');

% FR1 Config
tx1_FR1 = txsite(Name="TX1 FR1", Latitude=tx1_lat, Longitude=tx1_lon, ...
    AntennaHeight=30, TransmitterPower=60, TransmitterFrequency=4.7e9, Antenna=bsArray_FR1);

% FR2 Config  
tx1_FR2 = txsite(Name="TX1 FR2", Latitude=tx1_lat, Longitude=tx1_lon, ...
    AntennaHeight=30, TransmitterPower=2, TransmitterFrequency=28e9, Antenna=bsArray_FR2);

% TX2를 간섭원으로 설정 (SINR 계산용)
tx2_FR1_interferer = txsite(Name="TX2 FR1 Interferer", Latitude=tx2_lat, Longitude=tx2_lon, ...
    AntennaHeight=30, TransmitterPower=60, TransmitterFrequency=4.7e9, Antenna=bsArray_FR1);

tx2_FR2_interferer = txsite(Name="TX2 FR2 Interferer", Latitude=tx2_lat, Longitude=tx2_lon, ...
    AntennaHeight=30, TransmitterPower=2, TransmitterFrequency=28e9, Antenna=bsArray_FR2);

snr_tx1_FR1 = zeros(1, num_distances);
snr_tx1_FR2 = zeros(1, num_distances);
sinr_tx1_FR1 = zeros(1, num_distances);
sinr_tx1_FR2 = zeros(1, num_distances);

fprintf('%-10s | %-12s | %-12s | %-12s | %-12s\n', ...
    'Dist (m)', 'FR1 SNR(dB)', 'FR1 SINR(dB)', 'FR2 SNR(dB)', 'FR2 SINR(dB)');
fprintf('----------------------------------------------------------\n');

for idx = 1:num_distances
    rx = rx1_array{idx};
    
    % ========== FR1 ==========
    % Beamforming to RX
    [az_fr1, el_fr1] = angle(tx1_FR1, rx);
    tx1_FR1.AntennaAngle = [az_fr1, el_fr1];
    
    % Desired Signal Power (원하는 신호)
    desired_signal_FR1 = sigstrength(rx, tx1_FR1, rtpm);  % dBm
    
    % Interference from TX2 (간섭 신호)
    [az_int_fr1, el_int_fr1] = angle(tx2_FR1_interferer, rx);
    tx2_FR1_interferer.AntennaAngle = [az_int_fr1, el_int_fr1];
    interference_FR1 = sigstrength(rx, tx2_FR1_interferer, rtpm);  % dBm
    
    % Convert to linear scale
    desired_linear = 10^(desired_signal_FR1/10);  % mW
    interference_linear = 10^(interference_FR1/10);  % mW
    noise_linear = 10^(noise_floor_FR1/10);  % mW
    
    % SNR Calculation (No interference)
    snr_linear = desired_linear / noise_linear;
    raw_snr_FR1 = 10*log10(snr_linear);  % dB
    snr_tx1_FR1(idx) = min(raw_snr_FR1, MAX_SNR_CAP);
    
    % SINR Calculation (With interference)
    sinr_linear = desired_linear / (noise_linear + interference_linear);
    raw_sinr_FR1 = 10*log10(sinr_linear);  % dB
    sinr_tx1_FR1(idx) = min(raw_sinr_FR1, MAX_SNR_CAP);
    
    % ========== FR2 ==========
    % Beamforming to RX
    [az_fr2, el_fr2] = angle(tx1_FR2, rx);
    tx1_FR2.AntennaAngle = [az_fr2, el_fr2];
    
    % Desired Signal Power
    desired_signal_FR2 = sigstrength(rx, tx1_FR2, rtpm);
    
    % Interference from TX2
    [az_int_fr2, el_int_fr2] = angle(tx2_FR2_interferer, rx);
    tx2_FR2_interferer.AntennaAngle = [az_int_fr2, el_int_fr2];
    interference_FR2 = sigstrength(rx, tx2_FR2_interferer, rtpm);
    
    % Convert to linear scale
    desired_linear = 10^(desired_signal_FR2/10);
    interference_linear = 10^(interference_FR2/10);
    noise_linear = 10^(noise_floor_FR2/10);
    
    % SNR Calculation
    snr_linear = desired_linear / noise_linear;
    raw_snr_FR2 = 10*log10(snr_linear);
    snr_tx1_FR2(idx) = min(raw_snr_FR2, MAX_SNR_CAP);
    
    % SINR Calculation
    sinr_linear = desired_linear / (noise_linear + interference_linear);
    raw_sinr_FR2 = 10*log10(sinr_linear);
    sinr_tx1_FR2(idx) = min(raw_sinr_FR2, MAX_SNR_CAP);
    
    fprintf('%10.1f | %12.2f | %12.2f | %12.2f | %12.2f\n', ...
        actual_dist_tx1(idx), snr_tx1_FR1(idx), sinr_tx1_FR1(idx), ...
        snr_tx1_FR2(idx), sinr_tx1_FR2(idx));
end

% === TX2 Analysis ===
fprintf('\n[TX2 Analysis - Seoul Airport]\n');
fprintf('----------------------------------------------------------\n');

% FR1 Config
tx2_FR1 = txsite(Name="TX2 FR1", Latitude=tx2_lat, Longitude=tx2_lon, ...
    AntennaHeight=30, TransmitterPower=60, TransmitterFrequency=4.7e9, Antenna=bsArray_FR1);

% FR2 Config
tx2_FR2 = txsite(Name="TX2 FR2", Latitude=tx2_lat, Longitude=tx2_lon, ...
    AntennaHeight=30, TransmitterPower=2, TransmitterFrequency=28e9, Antenna=bsArray_FR2);

% TX1을 간섭원으로 설정
tx1_FR1_interferer = txsite(Name="TX1 FR1 Interferer", Latitude=tx1_lat, Longitude=tx1_lon, ...
    AntennaHeight=30, TransmitterPower=60, TransmitterFrequency=4.7e9, Antenna=bsArray_FR1);

tx1_FR2_interferer = txsite(Name="TX1 FR2 Interferer", Latitude=tx1_lat, Longitude=tx1_lon, ...
    AntennaHeight=30, TransmitterPower=2, TransmitterFrequency=28e9, Antenna=bsArray_FR2);

snr_tx2_FR1 = zeros(1, num_distances);
snr_tx2_FR2 = zeros(1, num_distances);
sinr_tx2_FR1 = zeros(1, num_distances);
sinr_tx2_FR2 = zeros(1, num_distances);

fprintf('%-10s | %-12s | %-12s | %-12s | %-12s\n', ...
    'Dist (m)', 'FR1 SNR(dB)', 'FR1 SINR(dB)', 'FR2 SNR(dB)', 'FR2 SINR(dB)');
fprintf('----------------------------------------------------------\n');

for idx = 1:num_distances
    rx = rx2_array{idx};
    
    % FR1
    [az_fr1, el_fr1] = angle(tx2_FR1, rx);
    tx2_FR1.AntennaAngle = [az_fr1, el_fr1];
    desired_signal_FR1 = sigstrength(rx, tx2_FR1, rtpm);
    
    [az_int_fr1, el_int_fr1] = angle(tx1_FR1_interferer, rx);
    tx1_FR1_interferer.AntennaAngle = [az_int_fr1, el_int_fr1];
    interference_FR1 = sigstrength(rx, tx1_FR1_interferer, rtpm);
    
    desired_linear = 10^(desired_signal_FR1/10);
    interference_linear = 10^(interference_FR1/10);
    noise_linear = 10^(noise_floor_FR1/10);
    
    snr_linear = desired_linear / noise_linear;
    raw_snr_FR1 = 10*log10(snr_linear);
    snr_tx2_FR1(idx) = min(raw_snr_FR1, MAX_SNR_CAP);
    
    sinr_linear = desired_linear / (noise_linear + interference_linear);
    raw_sinr_FR1 = 10*log10(sinr_linear);
    sinr_tx2_FR1(idx) = min(raw_sinr_FR1, MAX_SNR_CAP);
    
    % FR2
    [az_fr2, el_fr2] = angle(tx2_FR2, rx);
    tx2_FR2.AntennaAngle = [az_fr2, el_fr2];
    desired_signal_FR2 = sigstrength(rx, tx2_FR2, rtpm);
    
    [az_int_fr2, el_int_fr2] = angle(tx1_FR2_interferer, rx);
    tx1_FR2_interferer.AntennaAngle = [az_int_fr2, el_int_fr2];
    interference_FR2 = sigstrength(rx, tx1_FR2_interferer, rtpm);
    
    desired_linear = 10^(desired_signal_FR2/10);
    interference_linear = 10^(interference_FR2/10);
    noise_linear = 10^(noise_floor_FR2/10);
    
    snr_linear = desired_linear / noise_linear;
    raw_snr_FR2 = 10*log10(snr_linear);
    snr_tx2_FR2(idx) = min(raw_snr_FR2, MAX_SNR_CAP);
    
    sinr_linear = desired_linear / (noise_linear + interference_linear);
    raw_sinr_FR2 = 10*log10(sinr_linear);
    sinr_tx2_FR2(idx) = min(raw_sinr_FR2, MAX_SNR_CAP);
    
    fprintf('%10.1f | %12.2f | %12.2f | %12.2f | %12.2f\n', ...
        actual_dist_tx2(idx), snr_tx2_FR1(idx), sinr_tx2_FR1(idx), ...
        snr_tx2_FR2(idx), sinr_tx2_FR2(idx));
end

%% Visualization
fprintf('\n========================================================\n');
fprintf('              Generating Plots...\n');
fprintf('========================================================\n');

% Figure 1: SNR Comparison
figure('Name', 'Distance vs SNR', 'Position', [100, 100, 1400, 500]);

subplot(1, 2, 1);
hold on; grid on;
plot(actual_dist_tx1, snr_tx1_FR1, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR1 (4.7GHz, 60W)');
plot(actual_dist_tx1, snr_tx1_FR2, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR2 (28GHz, 2W)');
yline(0, 'k--', 'LineWidth', 1.5, 'DisplayName', 'SNR = 0dB');
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('TX1 - Distance vs SNR (No Interference)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, max(actual_dist_tx1)+20]);
hold off;

subplot(1, 2, 2);
hold on; grid on;
plot(actual_dist_tx2, snr_tx2_FR1, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR1 (4.7GHz, 60W)');
plot(actual_dist_tx2, snr_tx2_FR2, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR2 (28GHz, 2W)');
yline(0, 'k--', 'LineWidth', 1.5, 'DisplayName', 'SNR = 0dB');
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('TX2 - Distance vs SNR (No Interference)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, max(actual_dist_tx2)+20]);
hold off;

% Figure 2: SINR Comparison
figure('Name', 'Distance vs SINR', 'Position', [150, 150, 1400, 500]);

subplot(1, 2, 1);
hold on; grid on;
plot(actual_dist_tx1, sinr_tx1_FR1, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR1 (4.7GHz, 60W)');
plot(actual_dist_tx1, sinr_tx1_FR2, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR2 (28GHz, 2W)');
yline(0, 'k--', 'LineWidth', 1.5, 'DisplayName', 'SINR = 0dB');
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('SINR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('TX1 - Distance vs SINR (With Interference from TX2)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, max(actual_dist_tx1)+20]);
hold off;

subplot(1, 2, 2);
hold on; grid on;
plot(actual_dist_tx2, sinr_tx2_FR1, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR1 (4.7GHz, 60W)');
plot(actual_dist_tx2, sinr_tx2_FR2, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR2 (28GHz, 2W)');
yline(0, 'k--', 'LineWidth', 1.5, 'DisplayName', 'SINR = 0dB');
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('SINR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('TX2 - Distance vs SINR (With Interference from TX1)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, max(actual_dist_tx2)+20]);
hold off;

% Figure 3: SNR vs SINR Comparison
figure('Name', 'SNR vs SINR Impact', 'Position', [200, 200, 1400, 500]);

subplot(1, 2, 1);
hold on; grid on;
plot(actual_dist_tx1, snr_tx1_FR1, 'r--o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'DisplayName', 'FR1 SNR');
plot(actual_dist_tx1, sinr_tx1_FR1, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR1 SINR');
plot(actual_dist_tx1, snr_tx1_FR2, 'b--s', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'DisplayName', 'FR2 SNR');
plot(actual_dist_tx1, sinr_tx1_FR2, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR2 SINR');
yline(0, 'k--', 'LineWidth', 1.5);
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('SNR / SINR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('TX1 - Impact of Interference on Signal Quality', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, max(actual_dist_tx1)+20]);
hold off;

subplot(1, 2, 2);
hold on; grid on;
plot(actual_dist_tx2, snr_tx2_FR1, 'r--o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'DisplayName', 'FR1 SNR');
plot(actual_dist_tx2, sinr_tx2_FR1, 'r-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR1 SINR');
plot(actual_dist_tx2, snr_tx2_FR2, 'b--s', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'DisplayName', 'FR2 SNR');
plot(actual_dist_tx2, sinr_tx2_FR2, 'b-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'FR2 SINR');
yline(0, 'k--', 'LineWidth', 1.5);
xlabel('Distance from BS (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('SNR / SINR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('TX2 - Impact of Interference on Signal Quality', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, max(actual_dist_tx2)+20]);
hold off;

fprintf('\n========================================================\n');
fprintf('              Analysis Complete!\n');
fprintf('========================================================\n');