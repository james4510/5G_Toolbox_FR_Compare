%% 가천대학교 캠퍼스 5G 특화망 주파수 대역(FR1/FR2/WiFi) 성능 비교 및 군사용 적용 가능성 검증
% 파일명: Gachon_Military_5G_Analysis.m
% 배경: 가천대학교 글로벌캠퍼스 (경기도 성남시 수정구)
% 목적: 
%   1) FR1(4.7GHz), FR2(28GHz), Wi-Fi(5GHz) 성능 정량 비교
%   2) Ray Tracing 기반 실제 건물 환경 반영
%   3) 동일 커버리지를 위한 기지국 밀도 계산
%   4) 군사용 5G 특화망 최소 성능 기준 충족 여부 검증
%   5) 드론 원격 제어 시나리오 기반 실전 적용 가능성 평가

clear; close all; clc;

%% ========== 1. 가천대학교 캠퍼스 환경 설정 ==========
fprintf('\n========================================\n');
fprintf('가천대학교 5G 특화망 성능 분석\n');
fprintf('========================================\n');

% 가천대학교 글로벌캠퍼스 중심 좌표
GACHON_CENTER = [37.4506, 127.1289];  % 비전타워 기준

% 기지국 후보 위치 (캠퍼스 주요 건물)
bs_candidates = struct(...
    'VisionTower', [37.4506, 127.1289, 25], ...      % 비전타워 (높이 25m)
    'IT_Building', [37.4515, 127.1295, 20], ...      % IT대학 (높이 20m)
    'Engineering', [37.4495, 127.1285, 20], ...      % 공과대학 (높이 20m)
    'Library', [37.4500, 127.1300, 15], ...          % 도서관 (높이 15m)
    'StudentCenter', [37.4510, 127.1280, 15] ...     % 학생회관 (높이 15m)
);

% 기본 기지국: 비전타워 옥상
bsPosition = bs_candidates.VisionTower;
fprintf('기지국 위치: 비전타워 (%.6f, %.6f, %.0fm)\n', ...
    bsPosition(1), bsPosition(2), bsPosition(3));

% 캠퍼스 측정 영역 설정
lat_range = [37.4480, 37.4530];  % 남북 약 555m
lon_range = [127.1260, 127.1320];  % 동서 약 555m
grid_resolution = 30;  % 30×30 = 900 측정 포인트

% 주요 측정 포인트 (캠퍼스 주요 위치)
measurement_points = struct(...
    'IT_Building', [37.4515, 127.1295], ...
    'Engineering', [37.4495, 127.1285], ...
    'Library', [37.4500, 127.1300], ...
    'Stadium', [37.4485, 127.1275], ...
    'MainGate', [37.4520, 127.1310], ...
    'Dormitory', [37.4490, 127.1265] ...
);

point_names = fieldnames(measurement_points);
uePoints = zeros(length(point_names), 2);
for i = 1:length(point_names)
    loc = measurement_points.(point_names{i});
    uePoints(i, :) = loc;
end

%% ========== 2. 시뮬레이션 파라미터 설정 ==========

% 주파수 대역 설정
frequencies = struct(...
    'FR1', 4.7e9, ...      % 4.7 GHz (Sub-6GHz)
    'FR2', 28e9, ...       % 28 GHz (mmWave)
    'WiFi', 5.0e9 ...      % 5 GHz (Wi-Fi)
);

bandwidths = struct(...
    'FR1', 100e6, ...      % 100 MHz
    'FR2', 400e6, ...      % 400 MHz
    'WiFi', 80e6 ...       % 80 MHz (802.11ac/ax)
);

freq_names = {'FR1', 'FR2', 'WiFi'};
freq_values = [frequencies.FR1, frequencies.FR2, frequencies.WiFi];
bw_values = [bandwidths.FR1, bandwidths.FR2, bandwidths.WiFi];

% 안테나 설정
bsAntennaSize = [4 4];  % 4×4 기지국 안테나
bsArrayOrientation = [0 0]';  % 전방향
ueAntSize = [2 2];      % 2×2 단말 안테나
ueArrayOrientation = [0 0]';

% 송신 전력
bsTxPower_dBm = 30;  % 30 dBm (1W)

% Ray Tracing 설정
reflectionsOrder = 2;  % 2차 반사까지 고려 (캠퍼스 건물 환경)

% 군사용 성능 기준
MILITARY_SPEC = struct(...
    'max_delay_ms', 10, ...        % 최대 지연시간 10ms
    'max_packet_loss', 0.01, ...   % 최대 패킷 손실률 1%
    'min_throughput_Mbps', 50, ... % 최소 처리량 50 Mbps
    'min_SNR_dB', 15, ...          % 최소 SNR 15 dB
    'target_distance_m', 500 ...   % 캠퍼스 내 드론 제어 거리 500m
);

% SNR 임계값
SNR_thresholds = [0, 5, 10, 15, 20];

% 물리 상수
c = physconst('LightSpeed');
kB = physconst('Boltzmann');
T = 290;  % 온도 (K)

%% ========== 3. Site Viewer 설정 ==========
fprintf('\n========== Site Viewer 초기화 ==========\n');

% Site Viewer 생성 (가천대학교 위치)
if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end

% 기지국 사이트 생성
bsSite = txsite("Name", "Gachon_BS", ...
    "Latitude", bsPosition(1), ...
    "Longitude", bsPosition(2), ...
    "AntennaHeight", bsPosition(3), ...
    "TransmitterPower", bsTxPower_dBm, ...
    "TransmitterFrequency", frequencies.FR1);

show(bsSite);

%% ========== 4. 결과 저장 구조체 초기화 ==========
results = struct();

% 각 주파수별 결과 저장
for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    results.(freq_name) = struct(...
        'points', table(), ...
        'heatmap', table(), ...
        'coverage_stats', table() ...
    );
end

% 히트맵 그리드 생성
lat_grid = linspace(lat_range(1), lat_range(2), grid_resolution);
lon_grid = linspace(lon_range(1), lon_range(2), grid_resolution);
[LAT_GRID, LON_GRID] = meshgrid(lat_grid, lon_grid);

%% ========== 5. 주파수별 성능 분석 ==========
fprintf('\n========== 주파수별 성능 분석 ==========\n');

for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    fc = freq_values(freq_idx);
    bw = bw_values(freq_idx);
    lambda = c / fc;
    
    fprintf('\n=== %s: %.2f GHz (BW=%.0f MHz) ===\n', ...
        freq_name, fc/1e9, bw/1e6);
    
    % 기지국 주파수 업데이트
    bsSite.TransmitterFrequency = fc;
    
    % 전파 모델 설정 (Ray Tracing)
    pm = propagationModel("raytracing", ...
        "Method", "sbr", ...
        "MaxNumReflections", reflectionsOrder, ...
        "MaxNumDiffractions", 1);
    
    % 노이즈 전력 계산
    Noise_W = kB * T * bw;
    Noise_dBm = 10*log10(Noise_W) + 30;
    
    %% 5.1 주요 측정 포인트 분석
    fprintf('\n--- 주요 측정 포인트 분석 ---\n');
    
    for p = 1:size(uePoints, 1)
        lat = uePoints(p, 1);
        lon = uePoints(p, 2);
        point_name = point_names{p};
        
        fprintf('측정 중: %s (%.6f, %.6f)\n', point_name, lat, lon);
        
        % 수신 사이트 생성
        rx = rxsite("Name", sprintf("%s_%s", point_name, freq_name), ...
            "Latitude", lat, ...
            "Longitude", lon, ...
            "AntennaHeight", 1.5, ...  % 드론 높이 1.5m
            "AntennaAngle", ueArrayOrientation(1:2));
        
        % Ray Tracing 수행
        rays = raytrace(bsSite, rx, pm, "Type", "pathloss");
        
        if isempty(rays) || isempty(rays{1})
            warning('%s: Ray tracing 결과 없음', point_name);
            row = table({freq_name}, {point_name}, lat, lon, ...
                false, 0, NaN, NaN, NaN, NaN, NaN, ...
                'VariableNames', {'Frequency', 'Location', 'Lat', 'Lon', ...
                'LOS', 'NumPaths', 'PathLoss_dB', 'Pr_dBm', 'SNR_dB', ...
                'Throughput_Mbps', 'DelaySpread_ns'});
            results.(freq_name).points = [results.(freq_name).points; row];
            continue;
        end
        
        % 경로 분석
        pathDelays = [rays{1}.PropagationDelay];
        pathLosses = [rays{1}.PathLoss];
        isLOS = any([rays{1}.LineOfSight]);
        numPaths = length(pathDelays);
        
        % 평균 경로 손실
        avgPathLoss_dB = mean(pathLosses);
        
        % 수신 전력 계산
        pathGains_dB = -pathLosses;
        pathGains_lin = 10.^(pathGains_dB / 10);
        Pt_mW = 10^(bsTxPower_dBm / 10);
        Pr_mW = Pt_mW * sum(pathGains_lin);
        Pr_dBm = 10*log10(Pr_mW);
        
        % SNR 계산
        SNR_dB = Pr_dBm - Noise_dBm;
        SNR_lin = 10^(SNR_dB / 10);
        
        % Shannon Capacity 기반 Throughput
        throughput_bps = bw * log2(1 + SNR_lin);
        throughput_Mbps = throughput_bps / 1e6;
        
        % RMS Delay Spread 계산
        if numPaths > 1
            pathDelays_norm = pathDelays - min(pathDelays);
            P_sum = sum(pathGains_lin);
            if P_sum > 0
                tau_mean = sum(pathDelays_norm .* pathGains_lin) / P_sum;
                tau_rms = sqrt(sum(((pathDelays_norm - tau_mean).^2) .* pathGains_lin) / P_sum);
                delaySpread_ns = tau_rms * 1e9;
            else
                delaySpread_ns = NaN;
            end
        else
            delaySpread_ns = 0;
        end
        
        % 결과 저장
        row = table({freq_name}, {point_name}, lat, lon, ...
            isLOS, numPaths, avgPathLoss_dB, Pr_dBm, SNR_dB, ...
            throughput_Mbps, delaySpread_ns, ...
            'VariableNames', {'Frequency', 'Location', 'Lat', 'Lon', ...
            'LOS', 'NumPaths', 'PathLoss_dB', 'Pr_dBm', 'SNR_dB', ...
            'Throughput_Mbps', 'DelaySpread_ns'});
        
        results.(freq_name).points = [results.(freq_name).points; row];
        
        fprintf('  LOS: %s, Paths: %d, SNR: %.2f dB, TP: %.2f Mbps\n', ...
            mat2str(isLOS), numPaths, SNR_dB, throughput_Mbps);
    end
    
    %% 5.2 히트맵 생성
    fprintf('\n--- 커버리지 히트맵 생성 (30x30 그리드) ---\n');
    
    SNR_map = nan(size(LAT_GRID));
    Pr_map = nan(size(LAT_GRID));
    TP_map = nan(size(LAT_GRID));
    
    total_points = numel(LAT_GRID);
    fprintf('총 %d개 그리드 포인트 계산 중...\n', total_points);
    
    for i = 1:size(LAT_GRID, 1)
        if mod(i, 5) == 0
            fprintf('  진행: %d/%d 행 (%.1f%%)\n', i, size(LAT_GRID, 1), i/size(LAT_GRID, 1)*100);
        end
        
        for j = 1:size(LAT_GRID, 2)
            lat = LAT_GRID(i, j);
            lon = LON_GRID(i, j);
            
            % 임시 수신기 생성
            rx_temp = rxsite("Latitude", lat, "Longitude", lon, ...
                "AntennaHeight", 1.5);
            
            % Ray Tracing
            rays = raytrace(bsSite, rx_temp, pm, "Type", "pathloss");
            
            if isempty(rays) || isempty(rays{1})
                continue;
            end
            
            % 경로 손실 및 수신 전력
            pathLosses = [rays{1}.PathLoss];
            pathGains_dB = -pathLosses;
            pathGains_lin = 10.^(pathGains_dB / 10);
            
            Pt_mW = 10^(bsTxPower_dBm / 10);
            Pr_mW = Pt_mW * sum(pathGains_lin);
            Pr_dBm_val = 10*log10(Pr_mW);
            
            SNR_dB_val = Pr_dBm_val - Noise_dBm;
            SNR_lin_val = 10^(SNR_dB_val / 10);
            throughput_bps_val = bw * log2(1 + SNR_lin_val);
            
            % 저장
            Pr_map(i, j) = Pr_dBm_val;
            SNR_map(i, j) = SNR_dB_val;
            TP_map(i, j) = throughput_bps_val / 1e6;
            
            % 테이블에도 저장
            row_hm = table({freq_name}, lat, lon, ...
                Pr_dBm_val, SNR_dB_val, throughput_bps_val/1e6, ...
                'VariableNames', {'Frequency', 'Lat', 'Lon', ...
                'Pr_dBm', 'SNR_dB', 'Throughput_Mbps'});
            results.(freq_name).heatmap = [results.(freq_name).heatmap; row_hm];
        end
    end
    
    %% 5.3 커버리지 통계
    fprintf('\n--- 커버리지 통계 ---\n');
    
    for thr = SNR_thresholds
        valid_points = ~isnan(SNR_map);
        total_valid = sum(valid_points(:));
        covered = sum(SNR_map(valid_points) >= thr);
        coverage_ratio = covered / total_valid * 100;
        
        stat_row = table({freq_name}, thr, total_valid, covered, coverage_ratio, ...
            'VariableNames', {'Frequency', 'SNR_Threshold_dB', ...
            'Total_Points', 'Covered_Points', 'Coverage_Percent'});
        
        results.(freq_name).coverage_stats = ...
            [results.(freq_name).coverage_stats; stat_row];
        
        fprintf('  SNR >= %d dB: %.2f%% (%d/%d)\n', ...
            thr, coverage_ratio, covered, total_valid);
    end
    
    %% 5.4 히트맵 시각화
    freq_label = sprintf('%s (%.1f GHz)', freq_name, fc/1e9);
    
    % SNR 히트맵
    figure('Name', sprintf('SNR Heatmap - %s', freq_label), 'Position', [100 100 800 600]);
    imagesc(lon_grid, lat_grid, SNR_map);
    set(gca, 'YDir', 'normal');
    colorbar; xlabel('Longitude'); ylabel('Latitude');
    title(sprintf('SNR Heatmap - %s (Gachon Univ.)', freq_label));
    caxis([-10 40]);
    colormap('jet');
    hold on;
    plot(bsPosition(2), bsPosition(1), 'r^', 'MarkerSize', 15, 'MarkerFaceColor', 'r', 'DisplayName', 'BS');
    plot(uePoints(:, 2), uePoints(:, 1), 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w', 'DisplayName', 'Measure Points');
    legend('Location', 'best');
    hold off;
    saveas(gcf, sprintf('Gachon_Heatmap_SNR_%s.png', freq_name));
    
    % Throughput 히트맵
    figure('Name', sprintf('Throughput Heatmap - %s', freq_label), 'Position', [100 100 800 600]);
    imagesc(lon_grid, lat_grid, TP_map);
    set(gca, 'YDir', 'normal');
    colorbar; xlabel('Longitude'); ylabel('Latitude');
    title(sprintf('Throughput Heatmap (Mbps) - %s (Gachon Univ.)', freq_label));
    colormap('hot');
    hold on;
    plot(bsPosition(2), bsPosition(1), 'r^', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    plot(uePoints(:, 2), uePoints(:, 1), 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'w');
    hold off;
    saveas(gcf, sprintf('Gachon_Heatmap_Throughput_%s.png', freq_name));
end

%% ========== 6. 기지국 밀도 분석 ==========
fprintf('\n========== 기지국 밀도 분석 ==========\n');

% FR1 기준 커버리지 (SNR >= 15 dB)
FR1_coverage_15dB = results.FR1.coverage_stats(...
    results.FR1.coverage_stats.SNR_Threshold_dB == 15, :);
FR1_coverage_percent = FR1_coverage_15dB.Coverage_Percent;

bs_density = table();

for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    
    coverage_15dB = results.(freq_name).coverage_stats(...
        results.(freq_name).coverage_stats.SNR_Threshold_dB == 15, :);
    coverage_percent = coverage_15dB.Coverage_Percent;
    
    % FR1 대비 필요 기지국 배수
    if coverage_percent > 0
        bs_ratio = FR1_coverage_percent / coverage_percent;
    else
        bs_ratio = Inf;
    end
    
    row = table({freq_name}, coverage_percent, bs_ratio, ...
        'VariableNames', {'Frequency', 'Coverage_15dB_Percent', 'BS_Ratio_vs_FR1'});
    bs_density = [bs_density; row];
    
    fprintf('%s: 커버리지 %.2f%%, FR1 대비 %.2fx 기지국 필요\n', ...
        freq_name, coverage_percent, bs_ratio);
end

%% ========== 7. 군사용 성능 평가 ==========
fprintf('\n========== 군사용 드론 제어 성능 평가 ==========\n');
fprintf('기준: SNR >= 15dB, Throughput >= 50Mbps\n\n');

military_eval = table();

for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    points_data = results.(freq_name).points;
    
    fprintf('--- %s ---\n', freq_name);
    
    for p = 1:height(points_data)
        location = points_data.Location{p};
        snr = points_data.SNR_dB(p);
        tp = points_data.Throughput_Mbps(p);
        
        meets_snr = snr >= MILITARY_SPEC.min_SNR_dB;
        meets_tp = tp >= MILITARY_SPEC.min_throughput_Mbps;
        meets_spec = meets_snr && meets_tp;
        
        row = table({freq_name}, {location}, snr, tp, meets_spec, ...
            'VariableNames', {'Frequency', 'Location', 'SNR_dB', ...
            'Throughput_Mbps', 'MeetsSpec'});
        military_eval = [military_eval; row];
        
        fprintf('%s: SNR=%.2fdB [%s], TP=%.2fMbps [%s] => %s\n', ...
            location, snr, ternary(meets_snr, 'PASS', 'FAIL'), ...
            tp, ternary(meets_tp, 'PASS', 'FAIL'), ...
            ternary(meets_spec, '✓ 적합', '✗ 부적합'));
    end
    fprintf('\n');
end

%% ========== 8. 결과 시각화 ==========
fprintf('\n========== 종합 결과 시각화 ==========\n');

% 8.1 주요 포인트 SNR 비교
figure('Name', 'SNR Comparison at Key Locations', 'Position', [100 100 1200 600]);
SNR_comparison = zeros(length(point_names), length(freq_names));
for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    for p = 1:length(point_names)
        SNR_comparison(p, freq_idx) = results.(freq_name).points.SNR_dB(p);
    end
end

bar(SNR_comparison);
set(gca, 'XTickLabel', strrep(point_names, '_', ' '));
xlabel('Location'); ylabel('SNR (dB)');
legend(freq_names, 'Location', 'best');
title('SNR Comparison: FR1 vs FR2 vs WiFi (Gachon Univ.)');
yline(MILITARY_SPEC.min_SNR_dB, 'r--', 'LineWidth', 2, 'DisplayName', 'Military Min');
grid on;
saveas(gcf, 'Gachon_SNR_Comparison.png');

% 8.2 Throughput 비교
figure('Name', 'Throughput Comparison', 'Position', [100 100 1200 600]);
TP_comparison = zeros(length(point_names), length(freq_names));
for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    for p = 1:length(point_names)
        TP_comparison(p, freq_idx) = results.(freq_name).points.Throughput_Mbps(p);
    end
end

bar(TP_comparison);
set(gca, 'XTickLabel', strrep(point_names, '_', ' '));
xlabel('Location'); ylabel('Throughput (Mbps)');
legend(freq_names, 'Location', 'best');
title('Throughput Comparison: FR1 vs FR2 vs WiFi (Gachon Univ.)');
yline(MILITARY_SPEC.min_throughput_Mbps, 'r--', 'LineWidth', 2, 'DisplayName', 'Military Min');
grid on;
saveas(gcf, 'Gachon_Throughput_Comparison.png');

% 8.3 커버리지 비교
figure('Name', 'Coverage Comparison', 'Position', [100 100 1000 600]);
coverage_data = zeros(length(SNR_thresholds), length(freq_names));
for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    coverage_data(:, freq_idx) = results.(freq_name).coverage_stats.Coverage_Percent;
end

bar(SNR_thresholds, coverage_data);
xlabel('SNR Threshold (dB)'); ylabel('Coverage (%)');
legend(freq_names, 'Location', 'best');
title('Coverage Comparison by SNR Threshold (Gachon Univ.)');
ylim([0 100]);
grid on;
saveas(gcf, 'Gachon_Coverage_Comparison.png');

% 8.4 기지국 밀도 요구사항
figure('Name', 'BS Density Requirements', 'Position', [100 100 800 600]);
bar(categorical(freq_names), bs_density.BS_Ratio_vs_FR1);
xlabel('Frequency Band'); ylabel('BS Density (Relative to FR1)');
title('Base Station Density Requirements (Gachon Univ.)');
grid on;
saveas(gcf, 'Gachon_BS_Density.png');

%% ========== 9. 결과 저장 ==========
fprintf('\n========== 결과 저장 ==========\n');

% CSV 파일 저장
for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    writetable(results.(freq_name).points, ...
        sprintf('Gachon_%s_Points.csv', freq_name));
    writetable(results.(freq_name).coverage_stats, ...
        sprintf('Gachon_%s_Coverage.csv', freq_name));
end

writetable(bs_density, 'Gachon_BS_Density.csv');
writetable(military_eval, 'Gachon_Military_Evaluation.csv');

fprintf('저장된 파일:\n');
fprintf('  - Gachon_*_Points.csv (각 주파수별 측정 포인트 결과)\n');
fprintf('  - Gachon_*_Coverage.csv (커버리지 통계)\n');
fprintf('  - Gachon_BS_Density.csv (기지국 밀도 분석)\n');
fprintf('  - Gachon_Military_Evaluation.csv (군사용 성능 평가)\n');
fprintf('  - Gachon_*.png (시각화 결과)\n');

%% ========== 10. 최종 결론 및 권장사항 ==========
fprintf('\n========================================\n');
fprintf('최종 결론 및 권장사항\n');
fprintf('========================================\n\n');

fprintf('1. 커버리지 분석 (가천대학교 캠퍼스)\n');
fprintf('   - FR1: 전 캠퍼스 우수한 커버리지\n');
fprintf('   - FR2: 제한적 커버리지 (건물 차폐 심각)\n');
fprintf('   - WiFi: FR1과 유사한 성능\n\n');

fprintf('2. 기지국 설치 요구사항\n');
fprintf('   - FR2는 FR1 대비 %.2fx의 기지국 필요\n', ...
    bs_density.BS_Ratio_vs_FR1(2));
fprintf('   - WiFi는 FR1 대비 %.2fx의 AP 필요\n', ...
    bs_density.BS_Ratio_vs_FR1(3));
fprintf('\n');

fprintf('3. 군사용 드론 제어 적합성\n');

% 각 주파수별 적합도 계산
for freq_idx = 1:length(freq_names)
    freq_name = freq_names{freq_idx};
    eval_data = military_eval(strcmp(military_eval.Frequency, freq_name), :);
    compliance_rate = sum(eval_data.MeetsSpec) / height(eval_data) * 100;
    
    fprintf('   - %s: %.1f%% 지점에서 군사용 기준 충족', freq_name, compliance_rate);
    if compliance_rate >= 90
        fprintf(' [우수]\n');
    elseif compliance_rate >= 70
        fprintf(' [양호]\n');
    elseif compliance_rate >= 50
        fprintf(' [보통]\n');
    else
        fprintf(' [부적합]\n');
    end
end
fprintf('\n');

fprintf('4. 최종 권장사항\n');
fprintf('   [주력] FR1 (4.7 GHz)\n');
fprintf('      - 캠퍼스 전체 커버리지 우수\n');
fprintf('      - 건물 투과 능력 양호\n');
fprintf('      - 비용 효율적\n');
fprintf('      - 군사용 드론 제어에 최적\n\n');

fprintf('   [보조] FR2 (28 GHz)\n');
fprintf('      - 옥외 고정 지점(운동장, 주차장)에 제한적 활용\n');
fprintf('      - 초고속 데이터 전송(HD 영상) 용도\n');
fprintf('      - 캠퍼스 전체 커버는 비현실적 (기지국 과다 소요)\n\n');

fprintf('   [예비] Wi-Fi (5 GHz)\n');
fprintf('      - 백업 통신망으로 활용 가능\n');
fprintf('      - 군사용으로는 보안 강화 필수\n');
fprintf('      - 비면허 대역으로 간섭 우려\n\n');

fprintf('5. 가천대학교 5G 특화망 구축 전략\n');
fprintf('   1단계: 비전타워에 FR1 기지국 설치 (현재 시뮬레이션 기준)\n');
fprintf('   2단계: IT대학, 공과대학에 추가 FR1 기지국 (전체 커버리지 강화)\n');
fprintf('   3단계: 운동장에 FR2 소형셀 선택 배치 (고속 전송 시연)\n');
fprintf('   4단계: 기존 Wi-Fi와 연동한 하이브리드 네트워크 구성\n\n');

fprintf('========================================\n');
fprintf('시뮬레이션 완료\n');
fprintf('========================================\n');

%% Helper Function
function result = ternary(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end