%% Urban Link and Coverage Analysis Using Ray Tracing
% - Import and visualize 3-D buildings data into Site Viewer
% - Define a transmitter site and ray tracing propagation model
%   corresponding to a 5G urban scenario
% - Analyze a link in non-line-of-sight conditions
% - Visualize coverage using the shooting and bouncing rays (SBR) ray
% tracing method with different numbers of reflections, diffractions, and
% launched rays

clear; close all; clc;

%% 거리 계산 함수 정의
%  두 위도/경도 사이의 거리를 미터 단위로 계산
function dist_m = calculate_distance(lat1, lon1, lat2, lon2)
    % Haversine 공식 사용
    R = 6371000; % 지구 반경 (미터)
    phi1 = deg2rad(lat1);
    phi2 = deg2rad(lat2);
    delta_phi = deg2rad(lat2 - lat1);
    delta_lambda = deg2rad(lon2 - lon1);
    
    a = sin(delta_phi/2)^2 + cos(phi1) * cos(phi2) * sin(delta_lambda/2)^2;
    c = 2 * atan2(sqrt(a), sqrt(1-a));
    dist_m = R * c;
end

%% Import and Visualize buildings Data
viewer = siteviewer(Buildings="seongnam.osm", Basemap="topographic");

%% =======================================================
%%                Define Transmitter Sites
%% =======================================================
tx1 = txsite(Name="Small cell transmitter A - 4.7 GHz", ...
    Latitude=37.455715, ...
    Longitude=127.133562, ...
    AntennaHeight=80, ...
    TransmitterPower=5, ...
    TransmitterFrequency=4.7e9);

tx2 = txsite(Name="Small cell transmitter B - 28 GHz", ...
    Latitude=37.4541, ...
    Longitude=127.1210, ...
    AntennaHeight=80, ...
    TransmitterPower=5, ...
    TransmitterFrequency=28e9);
show(tx1); show(tx2);

rtpm = propagationModel("raytracing", ...
    Method="sbr", ...
    MaxNumReflections=2, ...
    BuildingsMaterial="PEC", ...
    TerrainMaterial="PEC"); % PEC = Perfect Electrical Conductors

coverage(tx1, rtpm, ...
    SignalStrengths=-120:-5, ...
    MaxRange=500, ...
    Resolution=3, ...
    Transparency=0.6)

coverage(tx2, rtpm, ...
    SignalStrengths=-120:-5, ...
    MaxRange=500, ...
    Resolution=3, ...
    Transparency=0.6)

%% =======================================================
%%                Define Receiver Sites
%% =======================================================

rx1_1 = rxsite(Name="Small cell receiver #1-1", ...
    Latitude=37.456715, ...
    Longitude=127.132562, ...
    AntennaHeight=1);

rx1_2 = rxsite(Name="Small cell receiver #1-2", ...
    Latitude=37.4576, ...
    Longitude=127.1328, ...
    AntennaHeight=1);

rx1_3 = rxsite(Name="Small cell receiver #1-3", ...
    Latitude=37.4563, ...
    Longitude=127.1321, ...
    AntennaHeight=1);

los(tx1, rx1_1)
los(tx1, rx1_2)
los(tx1, rx1_3)

rx2_1 = rxsite(Name="Small cell receiver #2-1", ...
    Latitude=37.4551, ...
    Longitude=127.1210, ...
    AntennaHeight=1);

rx2_2 = rxsite(Name="Small cell receiver #2-2", ...
    Latitude=37.4544, ...
    Longitude=127.1228, ...
    AntennaHeight=1);

rx2_3 = rxsite(Name="Small cell receiver #2-3", ...
    Latitude=37.4528, ...
    Longitude=127.1219, ...
    AntennaHeight=1);

los(tx2, rx2_1)
los(tx2, rx2_2)
los(tx2, rx2_3)

%% =======================================================
%%     UE-BS 거리 계산 및 신호 세기 분석
%% =======================================================

fprintf('\n========================================================\n');
fprintf('    Distance and Signal Strength Analysis\n');
fprintf('========================================================\n');

%% TX1 - RX1 그룹 분석
fprintf('\n=== TX1 (4.7 GHz) - UE Analysis ===\n');
fprintf('BS Location: (%.6f, %.6f)\n', tx1.Latitude, tx1.Longitude);
fprintf('%-15s %-15s %-20s\n', 'UE Name', 'Distance (m)', 'Rx Power (dBm)');
fprintf('%-15s %-15s %-20s\n', '---------------', '---------------', '--------------------');

% RX1-1
dist_tx1_rx1_1 = calculate_distance(tx1.Latitude, tx1.Longitude, ...
                                     rx1_1.Latitude, rx1_1.Longitude);
ss_rx1_1 = sigstrength(rx1_1, tx1, rtpm);
fprintf('%-15s %-15.2f %-20.2f\n', 'RX1-1', dist_tx1_rx1_1, ss_rx1_1);

% RX1-2
dist_tx1_rx1_2 = calculate_distance(tx1.Latitude, tx1.Longitude, ...
                                     rx1_2.Latitude, rx1_2.Longitude);
ss_rx1_2 = sigstrength(rx1_2, tx1, rtpm);
fprintf('%-15s %-15.2f %-20.2f\n', 'RX1-2', dist_tx1_rx1_2, ss_rx1_2);

% RX1-3
dist_tx1_rx1_3 = calculate_distance(tx1.Latitude, tx1.Longitude, ...
                                     rx1_3.Latitude, rx1_3.Longitude);
ss_rx1_3 = sigstrength(rx1_3, tx1, rtpm);
fprintf('%-15s %-15.2f %-20.2f\n', 'RX1-3', dist_tx1_rx1_3, ss_rx1_3);

%% TX2 - RX2 그룹 분석
fprintf('\n=== TX2 (28 GHz) - UE Analysis ===\n');
fprintf('BS Location: (%.6f, %.6f)\n', tx2.Latitude, tx2.Longitude);
fprintf('%-15s %-15s %-20s\n', 'UE Name', 'Distance (m)', 'Rx Power (dBm)');
fprintf('%-15s %-15s %-20s\n', '---------------', '---------------', '--------------------');

% RX2-1
dist_tx2_rx2_1 = calculate_distance(tx2.Latitude, tx2.Longitude, ...
                                     rx2_1.Latitude, rx2_1.Longitude);
ss_rx2_1 = sigstrength(rx2_1, tx2, rtpm);
fprintf('%-15s %-15.2f %-20.2f\n', 'RX2-1', dist_tx2_rx2_1, ss_rx2_1);

% RX2-2
dist_tx2_rx2_2 = calculate_distance(tx2.Latitude, tx2.Longitude, ...
                                     rx2_2.Latitude, rx2_2.Longitude);
ss_rx2_2 = sigstrength(rx2_2, tx2, rtpm);
fprintf('%-15s %-15.2f %-20.2f\n', 'RX2-2', dist_tx2_rx2_2, ss_rx2_2);

% RX2-3
dist_tx2_rx2_3 = calculate_distance(tx2.Latitude, tx2.Longitude, ...
                                     rx2_3.Latitude, rx2_3.Longitude);
ss_rx2_3 = sigstrength(rx2_3, tx2, rtpm);
fprintf('%-15s %-15.2f %-20.2f\n', 'RX2-3', dist_tx2_rx2_3, ss_rx2_3);

%% =======================================================
%%     결과 테이블 생성 (거리 포함)
%% =======================================================

results = table(...
    {'TX1-RX1'; 'TX1-RX2'; 'TX1-RX3'; 'TX2-RX1'; 'TX2-RX2'; 'TX2-RX3'}, ...
    [4.7; 4.7; 4.7; 28; 28; 28], ...
    [dist_tx1_rx1_1; dist_tx1_rx1_2; dist_tx1_rx1_3; ...
     dist_tx2_rx2_1; dist_tx2_rx2_2; dist_tx2_rx2_3], ...
    [ss_rx1_1; ss_rx1_2; ss_rx1_3; ss_rx2_1; ss_rx2_2; ss_rx2_3], ...
    'VariableNames', {'Link', 'Frequency_GHz', 'Distance_m', 'ReceivedPower_dBm'});

fprintf('\n========================================================\n');
fprintf('    Complete Results Summary\n');
fprintf('========================================================\n');
disp(results);

writetable(results, 'signal_strength_analysis.csv');
fprintf('\nSaved: signal_strength_analysis.csv\n');

%% =======================================================
%%     통계 요약
%% =======================================================

fprintf('\n========================================================\n');
fprintf('    Statistical Summary\n');
fprintf('========================================================\n');

% TX1 그룹 통계
tx1_distances = [dist_tx1_rx1_1, dist_tx1_rx1_2, dist_tx1_rx1_3];
tx1_powers = [ss_rx1_1, ss_rx1_2, ss_rx1_3];

fprintf('\n--- TX1 (4.7 GHz) Statistics ---\n');
fprintf('Distance: Min=%.2fm, Max=%.2fm, Avg=%.2fm\n', ...
        min(tx1_distances), max(tx1_distances), mean(tx1_distances));
fprintf('Rx Power: Min=%.2fdBm, Max=%.2fdBm, Avg=%.2fdBm\n', ...
        min(tx1_powers), max(tx1_powers), mean(tx1_powers));

% TX2 그룹 통계
tx2_distances = [dist_tx2_rx2_1, dist_tx2_rx2_2, dist_tx2_rx2_3];
tx2_powers = [ss_rx2_1, ss_rx2_2, ss_rx2_3];

fprintf('\n--- TX2 (28 GHz) Statistics ---\n');
fprintf('Distance: Min=%.2fm, Max=%.2fm, Avg=%.2fm\n', ...
        min(tx2_distances), max(tx2_distances), mean(tx2_distances));
fprintf('Rx Power: Min=%.2fdBm, Max=%.2fdBm, Avg=%.2fdBm\n', ...
        min(tx2_powers), max(tx2_powers), mean(tx2_powers));


%% 신호 세기 비교 그래프
figure('Name', 'Received Signal Strength Comparison', 'Position', [150 150 1000 500], 'Color', 'w');

% TX1 그룹
subplot(1, 2, 1);
hold on; grid on; box on;

bar([1, 2, 3], tx1_powers, 'FaceColor', [0.3 0.6 0.9], 'EdgeColor', 'k', 'LineWidth', 1);
ylabel('Received Power (dBm)', 'FontSize', 12);
xlabel('UE Index', 'FontSize', 12);
title('TX1 (4.7 GHz) - Received Power', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'XTickLabel', {'RX1-1', 'RX1-2', 'RX1-3'});
set(gca, 'FontSize', 11);

% 막대 위에 수치 표시
for i = 1:3
    text(i, tx1_powers(i) + 2, sprintf('%.2f dBm', tx1_powers(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end
hold off;

% TX2 그룹
subplot(1, 2, 2);
hold on; grid on; box on;

bar([1, 2, 3], tx2_powers, 'FaceColor', [0.9 0.5 0.2], 'EdgeColor', 'k', 'LineWidth', 1);
ylabel('Received Power (dBm)', 'FontSize', 12);
xlabel('UE Index', 'FontSize', 12);
title('TX2 (28 GHz) - Received Power', 'FontSize', 13, 'FontWeight', 'bold');
set(gca, 'XTickLabel', {'RX2-1', 'RX2-2', 'RX2-3'});
set(gca, 'FontSize', 11);

% 막대 위에 수치 표시
for i = 1:3
    text(i, tx2_powers(i) + 2, sprintf('%.2f dBm', tx2_powers(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end
hold off;

saveas(gcf, 'UE_Signal_Strength.png');
fprintf('Saved: UE_Signal_Strength.png\n');

%% 거리-신호세기 관계 그래프
figure('Name', 'Distance vs Power Relationship', 'Position', [200 200 800 600], 'Color', 'w');
hold on; grid on; box on;

% TX1 그룹
plot(tx1_distances, tx1_powers, 'o', 'MarkerSize', 12, ...
     'MarkerFaceColor', [0.3 0.6 0.9], 'MarkerEdgeColor', 'k', ...
     'LineWidth', 1.5, 'DisplayName', 'TX1 (4.7 GHz)');

% 각 점에 레이블 추가
for i = 1:3
    text(tx1_distances(i) + 5, tx1_powers(i) + 1, sprintf('RX1-%d', i), ...
         'FontSize', 9, 'Color', [0.2 0.4 0.7]);
end

% TX2 그룹
plot(tx2_distances, tx2_powers, 's', 'MarkerSize', 12, ...
     'MarkerFaceColor', [0.9 0.5 0.2], 'MarkerEdgeColor', 'k', ...
     'LineWidth', 1.5, 'DisplayName', 'TX2 (28 GHz)');

% 각 점에 레이블 추가
for i = 1:3
    text(tx2_distances(i) + 5, tx2_powers(i) + 1, sprintf('RX2-%d', i), ...
         'FontSize', 9, 'Color', [0.7 0.3 0.1]);
end

xlabel('Distance from BS (m)', 'FontSize', 13);
ylabel('Received Power (dBm)', 'FontSize', 13);
title('Distance vs Received Power', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 12);
set(gca, 'FontSize', 12, 'LineWidth', 1);
set(gca, 'GridLineStyle', ':', 'GridColor', [0.5 0.5 0.5], 'GridAlpha', 0.4);
hold off;

saveas(gcf, 'Distance_vs_Power.png');
fprintf('Saved: Distance_vs_Power.png\n');
fprintf('\nGenerated Files:\n');
fprintf('  - signal_strength_analysis.csv\n');
fprintf('  - UE_Distances.png\n');
fprintf('  - UE_Signal_Strength.png\n');
fprintf('  - Distance_vs_Power.png\n');
fprintf('========================================================\n');