%% FR1 vs FR2 분석: 실제 UE 위치만 분석 (히트맵 제거)

clear; close all; clc;

%% ----- 사용자 설정 -----
% BS 설정
bsPosition = [37.455715, 127.133562]; % lat, lon (기지국)
bsAntennaSize = [4 4];
bsArrayOrientation = [90 0].';

% 송신 전력 설정 (dBm)
Pt_dBm = 30;

% UE 원형 배치 설정
ue_distances = [15, 30, 45, 60, 75, 90];  % BS로부터의 거리 (미터)
ue_angular_spacing = 30;  % UE 간 각도 간격 (도)

% UE 안테나 파라미터
ueAntSize = [2 2];
ueArrayOrientation = [-30 45].';

% 반사 개수
reflectionsOrder = 1;

% 실험 주파수 및 대역폭
freqs = [4.7e9, 28e9];       % FR1, FR2
bws   = [100e6, 400e6];      % 대역폭
scs_list = [15e3, 120e3];    % Subcarrier Spacing

% SNR 임계값
SNR_thresholds = [0, 5, 10, 15, 20];

% OFDM 설정
SCS = 15; NRB = 52;

%% ----- 좌표 변환 함수 -----
meters_to_lat = @(m) m / 111000;
meters_to_lon = @(m, lat) m / (111000 * cosd(lat));
latlon_to_meters = @(lat1, lon1, lat2, lon2) distance(lat1, lon1, lat2, lon2) * 1000;

function [new_lat, new_lon] = offset_position(base_lat, base_lon, distance_m, bearing_deg)
    delta_lat_m = distance_m * cosd(bearing_deg);
    delta_lat = delta_lat_m / 111000;
    delta_lon_m = distance_m * sind(bearing_deg);
    delta_lon = delta_lon_m / (111000 * cosd(base_lat));
    new_lat = base_lat + delta_lat;
    new_lon = base_lon + delta_lon;
end
%% ----- UE 좌표 생성 -----
fprintf("\n========================================================\n");
fprintf("STEP 1: UE Coordinate Generation\n");
fprintf("========================================================\n");
fprintf("  BS Position: (%.6f, %.6f)\n", bsPosition(1), bsPosition(2));
fprintf("  Distances: %s m\n", mat2str(ue_distances));
fprintf("  Angular spacing: %d degrees\n", ue_angular_spacing);

uePoints = [];
ue_info = table();
point_idx = 0;

for dist_idx = 1:length(ue_distances)
    dist = ue_distances(dist_idx);
    num_ues_at_distance = floor(360 / ue_angular_spacing);
    
    fprintf("  Distance %dm: %d UEs\n", dist, num_ues_at_distance);
    
    for angle_idx = 1:num_ues_at_distance
        point_idx = point_idx + 1;
        bearing_deg = (angle_idx - 1) * ue_angular_spacing;
        [ue_lat, ue_lon] = offset_position(bsPosition(1), bsPosition(2), dist, bearing_deg);
        actual_distance = latlon_to_meters(bsPosition(1), bsPosition(2), ue_lat, ue_lon);
        distance_error = abs(actual_distance - dist);
        
        uePoints = [uePoints; ue_lat, ue_lon];
        
        ue_info_row = struct('UE_ID', point_idx, 'Distance_m', dist, ...
            'Bearing_deg', bearing_deg, 'Latitude', ue_lat, 'Longitude', ue_lon, ...
            'Actual_Distance_m', actual_distance, 'Distance_Error_m', distance_error);
        ue_info = [ue_info; struct2table(ue_info_row)];
    end
end

fprintf("  Total Generated: %d UE coordinates\n", size(uePoints, 1));
fprintf("  Average distance error: %.3f m\n", mean(ue_info.Distance_Error_m));

%% ----- UE 배치 패턴 시각화 -----
fprintf("\n========================================================\n");
fprintf("STEP 2: UE Deployment Visualization\n");
fprintf("========================================================\n");

fig1 = figure('Name', 'UE Deployment Pattern', 'Position', [100 100 1000 900], ...
    'Color', 'w', 'Visible', 'off');

% Geographic coordinates
subplot(2,1,1);
hold on; grid on; box on;
plot(bsPosition(2), bsPosition(1), '^', 'MarkerSize', 14, ...
    'MarkerFaceColor', [1 0 0], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

colors = lines(length(ue_distances));
for dist_idx = 1:length(ue_distances)
    dist = ue_distances(dist_idx);
    ues_at_dist = uePoints(ue_info.Distance_m == dist, :);
    plot(ues_at_dist(:,2), ues_at_dist(:,1), 'o', ...
        'Color', colors(dist_idx,:), 'MarkerSize', 8, ...
        'MarkerFaceColor', colors(dist_idx,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('%dm (%d UEs)', dist, size(ues_at_dist, 1)));
end

for dist = ue_distances
    theta = linspace(0, 2*pi, 100);
    circle_lat_radius = meters_to_lat(dist);
    circle_lon_radius = meters_to_lon(dist, bsPosition(1));
    circle_lats = bsPosition(1) + circle_lat_radius * cos(theta);
    circle_lons = bsPosition(2) + circle_lon_radius * sin(theta);
    plot(circle_lons, circle_lats, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
end

xlabel('Longitude', 'FontSize', 11, 'FontName', 'Arial');
ylabel('Latitude', 'FontSize', 11, 'FontName', 'Arial');
title('Geographic Coordinates', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'normal');
legend('Location', 'bestoutside', 'FontSize', 9);
axis equal;
set(gca, 'FontSize', 10, 'FontName', 'Arial');
hold off;

% Relative coordinates
subplot(2,1,2);
hold on; grid on; box on;
plot(0, 0, '^', 'MarkerSize', 14, 'MarkerFaceColor', [1 0 0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

for dist_idx = 1:length(ue_distances)
    dist = ue_distances(dist_idx);
    ues_at_dist_info = ue_info(ue_info.Distance_m == dist, :);
    x = dist * sind(ues_at_dist_info.Bearing_deg);
    y = dist * cosd(ues_at_dist_info.Bearing_deg);
    plot(x, y, 'o', 'Color', colors(dist_idx,:), 'MarkerSize', 8, ...
        'MarkerFaceColor', colors(dist_idx,:), 'LineWidth', 1.2);
end

for dist = ue_distances
    theta = linspace(0, 2*pi, 100);
    plot(dist*sin(theta), dist*cos(theta), '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
end

max_dist = max(ue_distances) * 1.1;
xlabel('East-West Distance (m)', 'FontSize', 11, 'FontName', 'Arial');
ylabel('North-South Distance (m)', 'FontSize', 11, 'FontName', 'Arial');
title('Relative Coordinates (BS at Origin)', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'normal');
axis equal;
xlim([-max_dist, max_dist]);
ylim([-max_dist, max_dist]);
set(gca, 'FontSize', 10, 'FontName', 'Arial');
hold off;

saveas(fig1, 'UE_Deployment_Pattern.png');
fprintf("  Created: UE_Deployment_Pattern.png\n");

%% ----- Siteviewer 초기화 -----
fprintf("\n========================================================\n");
fprintf("STEP 3: Siteviewer Initialization\n");
fprintf("========================================================\n");

if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end

fprintf("  Initializing site viewer...\n");

% BS site
fc_init = freqs(1);
bsSite = txsite("Name","Base Station", ...
    "Latitude",bsPosition(1),"Longitude",bsPosition(2),...
    "AntennaAngle",bsArrayOrientation(1:2),...
    "AntennaHeight",16,...
    "TransmitterFrequency",fc_init);
show(bsSite);

% UE sites
rxSites = cell(size(uePoints, 1), 1);
for p = 1:size(uePoints, 1)
    lat = uePoints(p, 1);
    lon = uePoints(p, 2);
    rxSites{p} = rxsite("Name", sprintf("UE_%d", p), ...
        "Latitude", lat, "Longitude", lon, ...
        "AntennaHeight", 1, ...
        "AntennaAngle", ueArrayOrientation(1:2));
    show(rxSites{p});
    if mod(p, 15) == 0
        fprintf("  Created %d/%d UE sites\n", p, size(uePoints, 1));
    end
end
%% ----- 준비 -----
c = physconst('LightSpeed');
ofdmInfo = nrOFDMInfo(NRB,SCS);

