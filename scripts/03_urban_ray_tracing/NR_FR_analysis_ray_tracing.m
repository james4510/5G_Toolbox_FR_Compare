%% 5G 통신 음영 지역 예측

clear all;
close all;
clc;

%% 1. 시뮬레이션 파라미터 설정
osmFile = 'seongnam_map.osm';
simulationName = '5G_Coverage_Analysis';

% 관심 영역 좌표
areaCenter = [37.455715, 127.133562];
areaRadius = 0.005;  % 약 500m

% 관심 영역 범위 설정
latitude = [areaCenter(1)-areaRadius, areaCenter(1)+areaRadius];
longitude = [areaCenter(2)-areaRadius, areaCenter(2)+areaRadius];

%% 2. 5G NR 물리 계층 파라미터
fc = 4.7e9;              % 반송파 주파수 (Hz)
SCS = 30;                % 부반송파 간격 (kHz)
NRB = 52;                % 리소스 블록 수

% OFDM 정보 계산
ofdmInfo = nrOFDMInfo(NRB, SCS);
fprintf('5G NR 파라미터:\n');
fprintf('  반송파 주파수: %.2f GHz\n', fc/1e9);
fprintf('  대역폭: %.2f MHz\n', ofdmInfo.SampleRate/1e6);
fprintf('  부반송파 간격: %d kHz\n', SCS);

%% 3. 기지국 설정
numBS = 1;
bsPositions = [areaCenter(1), areaCenter(2)];
bsAntennaHeight = 25;           % 안테나 높이 (m)
bsAntSize = [8 8];              % 안테나 배열 크기
bsArrayOrientation = [0; -10];  % [방위각; 고도]
txPower = 46;                   % 송신 전력 (dBm)
txGain = 15;                    % 송신 안테나 이득 (dBi)

fprintf('  송신 전력: %d dBm (%.1f W)\n', txPower, 10^((txPower-30)/10));

%% 4. UE 설정
gridResolution = 10;            % 그리드 해상도 (m)
ueAntennaHeight = 1.5;          % UE 높이 (m)
ueAntSize = [2 2];              % UE 안테나 배열

% UE 위치 그리드 생성
latStep = gridResolution / 111000;
lonStep = gridResolution / (111000 * cosd(areaCenter(1)));

[latGrid, lonGrid] = meshgrid(...
    latitude(1):latStep:latitude(2), ...
    longitude(1):lonStep:longitude(2));

numUE = numel(latGrid);
fprintf('  총 UE 수: %d\n', numUE);

%% 5. Open Street Map 파일 불러오기
if exist(osmFile, 'file')
    viewer = siteviewer("Buildings", osmFile, "Basemap", "openstreetmap");
else
    viewer = siteviewer("Basemap", "openstreetmap");
end

%% 6. 기지국 생성
fprintf('\n기지국 생성\n');

bsSites = cell(numBS, 1);
for i = 1:numBS
    bsSites{i} = txsite("Name", sprintf("BS_%d", i), ...
                       "Latitude", bsPositions(i,1), ...
                       "Longitude", bsPositions(i,2), ...
                       "AntennaHeight", bsAntennaHeight, ...
                       "AntennaAngle", bsArrayOrientation, ...
                       "TransmitterFrequency", fc, ...
                       "TransmitterPower", txPower);
end

%% 7. 레이 트레이싱 전파 모델 설정
fprintf('\n레이 트레이싱 모델 설정\n');

maxReflections = 2;
maxDiffractions = 0;

pm = propagationModel("raytracing", ...
                     "Method", "sbr", ...
                     "MaxNumReflections", maxReflections, ...
                     "MaxNumDiffractions", maxDiffractions, ...
                     "BuildingsMaterial", "concrete", ...
                     "TerrainMaterial", "concrete");

fprintf('  최대 반사: %d회\n', maxReflections);

%% 8. 레이 트레이싱 시뮬레이션 실행
fprintf('\n========================================\n');
fprintf('레이 트레이싱 시뮬레이션 시작\n');
fprintf('========================================\n');
fprintf('총 계산 포인트: %d\n\n', numUE);

% 결과 저장 배열 초기화
receivedPower = zeros(size(latGrid));
pathLoss = zeros(size(latGrid));
numRays = zeros(size(latGrid));
hasLOS = false(size(latGrid));

% 시뮬레이션 실행
tic;
progressStep = ceil(numUE / 20);

for i = 1:numUE
    if mod(i-1, progressStep) == 0
        fprintf('진행률: %d%% (%d/%d)\n', round(i/numUE*100), i, numUE);
    end
    
    tempRx = rxsite("Latitude", latGrid(i), ...
                   "Longitude", lonGrid(i), ...
                   "AntennaHeight", ueAntennaHeight);
    
    for j = 1:numBS
        try
            rays = raytrace(bsSites{j}, tempRx, pm, "Type", "pathloss");
            
            if ~isempty(rays) && ~isempty(rays{1})
                pathLoss(i) = rays{1}(1).PathLoss;
                receivedPower(i) = txPower - pathLoss(i);
                numRays(i) = length(rays{1});
                hasLOS(i) = any([rays{1}.LineOfSight]);
            else
                receivedPower(i) = -999;
                pathLoss(i) = 999;
            end
        catch ME
            warning('UE %d 오류: %s', i, ME.message);
            receivedPower(i) = -999;
            pathLoss(i) = 999;
        end
    end
end

elapsedTime = toc;
fprintf('\n레이 트레이싱 완료!\n');
fprintf('총 소요 시간: %.2f 초 (%.4f 초/포인트)\n\n', elapsedTime, elapsedTime/numUE);

%% 9. SINR 계산
fprintf('SINR 계산\n');

% 열잡음 전력 계산
k = 1.38e-23;
T = 290;
bandwidth = ofdmInfo.SampleRate;
noisePower_W = k * T * bandwidth;
noisePower_dBm = 10*log10(noisePower_W) + 30;

% 잡음 지수
noiseFigure = 7;  % dB
totalNoise_dBm = noisePower_dBm + noiseFigure;

% SINR 계산
SINR = receivedPower - totalNoise_dBm;

fprintf('  총 잡음: %.2f dBm\n', totalNoise_dBm);

%% 10. 음영 지역 분류
fprintf('\n음영 지역 분류...\n');

% SINR 임계값
minSINR = -6;
moderateSINR = 5;
goodSINR = 15;
excellentSINR = 25;

% 분류
deepShadow = SINR < minSINR;
poorCoverage = (SINR >= minSINR) & (SINR < moderateSINR);
moderateCoverage = (SINR >= moderateSINR) & (SINR < goodSINR);
goodCoverage = (SINR >= goodSINR) & (SINR < excellentSINR);
excellentCoverage = SINR >= excellentSINR;

% 비율 계산
totalPoints = numel(SINR);
deepShadowRatio = sum(deepShadow(:)) / totalPoints * 100;
poorCoverageRatio = sum(poorCoverage(:)) / totalPoints * 100;
moderateCoverageRatio = sum(moderateCoverage(:)) / totalPoints * 100;
goodCoverageRatio = sum(goodCoverage(:)) / totalPoints * 100;
excellentCoverageRatio = sum(excellentCoverage(:)) / totalPoints * 100;

fprintf('\n========================================\n');
fprintf('음영 지역 분석 결과\n');
fprintf('========================================\n');
fprintf('완전 음영 (SINR < %d dB):      %6.2f%%\n', minSINR, deepShadowRatio);
fprintf('불량 커버리지 (%d ~ %d dB):    %6.2f%%\n', minSINR, moderateSINR, poorCoverageRatio);
fprintf('중간 커버리지 (%d ~ %d dB):    %6.2f%%\n', moderateSINR, goodSINR, moderateCoverageRatio);
fprintf('양호 커버리지 (%d ~ %d dB):    %6.2f%%\n', goodSINR, excellentSINR, goodCoverageRatio);
fprintf('우수 커버리지 (SINR >= %d dB): %6.2f%%\n', excellentSINR, excellentCoverageRatio);
fprintf('========================================\n\n');

totalShadowRatio = deepShadowRatio + poorCoverageRatio;
fprintf('총 음영 지역 비율: %.2f%%\n\n', totalShadowRatio);


% Ground Truth 구조체
groundTruth = struct();
groundTruth.latitude = latGrid;
groundTruth.longitude = lonGrid;
groundTruth.receivedPower_dBm = receivedPower;
groundTruth.pathLoss_dB = pathLoss;
groundTruth.SINR_dB = SINR;
groundTruth.numRays = numRays;
groundTruth.hasLOS = hasLOS;

% 음영 분류
groundTruth.classification.deepShadow = deepShadow;
groundTruth.classification.poorCoverage = poorCoverage;
groundTruth.classification.moderateCoverage = moderateCoverage;
groundTruth.classification.goodCoverage = goodCoverage;
groundTruth.classification.excellentCoverage = excellentCoverage;

% 통계
groundTruth.statistics.deepShadowRatio = deepShadowRatio;
groundTruth.statistics.poorCoverageRatio = poorCoverageRatio;
groundTruth.statistics.moderateCoverageRatio = moderateCoverageRatio;
groundTruth.statistics.goodCoverageRatio = goodCoverageRatio;
groundTruth.statistics.excellentCoverageRatio = excellentCoverageRatio;
groundTruth.statistics.totalShadowRatio = totalShadowRatio;

% 시뮬레이션 파라미터
groundTruth.parameters.fc_Hz = fc;
groundTruth.parameters.bandwidth_Hz = bandwidth;
groundTruth.parameters.SCS_kHz = SCS;
groundTruth.parameters.NRB = NRB;
groundTruth.parameters.txPower_dBm = txPower;
groundTruth.parameters.txGain_dBi = txGain;
groundTruth.parameters.bsHeight_m = bsAntennaHeight;
groundTruth.parameters.ueHeight_m = ueAntennaHeight;
groundTruth.parameters.bsAntSize = bsAntSize;
groundTruth.parameters.ueAntSize = ueAntSize;
groundTruth.parameters.maxReflections = maxReflections;
groundTruth.parameters.maxDiffractions = maxDiffractions;
groundTruth.parameters.gridResolution_m = gridResolution;
groundTruth.parameters.noiseFigure_dB = noiseFigure;

% MAT 파일 저장
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
matFilename = sprintf('%s_%s.mat', simulationName, timestamp);
save(matFilename, 'groundTruth');
fprintf('  MAT 파일 저장: %s\n', matFilename);

% CSV 파일 저장
csvData = [latGrid(:), lonGrid(:), receivedPower(:), pathLoss(:), SINR(:), ...
          double(hasLOS(:)), numRays(:), ...
          double(deepShadow(:)), double(poorCoverage(:)), ...
          double(moderateCoverage(:)), double(goodCoverage(:)), ...
          double(excellentCoverage(:))];

csvHeaders = {'Latitude', 'Longitude', 'ReceivedPower_dBm', 'PathLoss_dB', ...
             'SINR_dB', 'HasLOS', 'NumRays', ...
             'DeepShadow', 'PoorCoverage', 'ModerateCoverage', ...
             'GoodCoverage', 'ExcellentCoverage'};

csvTable = array2table(csvData, 'VariableNames', csvHeaders);
csvFilename = sprintf('%s_%s.csv', simulationName, timestamp);
writetable(csvTable, csvFilename);
fprintf('  CSV 파일 저장: %s\n\n', csvFilename);

%% 12. 최종 통계
fprintf('========================================\n');
fprintf('최종 통계\n');
fprintf('========================================\n');

fprintf('\n[수신 전력]\n');
validPower = receivedPower(receivedPower > -999);
fprintf('  평균: %.2f dBm\n', mean(validPower));
fprintf('  최소: %.2f dBm\n', min(validPower));
fprintf('  최대: %.2f dBm\n', max(validPower));

fprintf('\n[SINR]\n');
validSINR = SINR(SINR > -100);
fprintf('  평균: %.2f dB\n', mean(validSINR));
fprintf('  최소: %.2f dB\n', min(validSINR));
fprintf('  최대: %.2f dB\n', max(validSINR));

fprintf('\n[레이 트레이싱]\n');
fprintf('  LOS 비율: %.2f%%\n', sum(hasLOS(:))/totalPoints*100);
fprintf('  평균 레이 개수: %.2f\n', mean(numRays(numRays>0)));

fprintf('\n========================================\n');
fprintf('시뮬레이션 완료\n');
fprintf('소요 시간: %.2f 분\n', elapsedTime/60);
fprintf('========================================\n\n');

fprintf('저장 파일:\n');
fprintf('  - %s\n', matFilename);
fprintf('  - %s\n', csvFilename);