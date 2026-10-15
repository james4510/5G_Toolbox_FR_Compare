%% [Step 0] 초기 설정 (이전 코드들과 동일하게 유지 필수)
clear; clc;

% 1. 맵 및 송신기 설정
bsPositions = [37.4516, 127.1295]; % 송신기 위치 (맵의 중심)
gridSize = 256;         % 이미지 해상도 (256x256)
mapWidthMeters = 500;   % 맵 크기 (500m)

% 2. 격자(Grid) 좌표 생성 (건물 맵/커버리지 맵과 동기화)
metersPerDegreeLat = 111000;
metersPerDegreeLon = 111000 * cosd(bsPositions(1));
deltaLat = (mapWidthMeters / 2) / metersPerDegreeLat;
deltaLon = (mapWidthMeters / 2) / metersPerDegreeLon;

latLim = [bsPositions(1) - deltaLat, bsPositions(1) + deltaLat];
lonLim = [bsPositions(2) - deltaLon, bsPositions(2) + deltaLon];

% 위도(Y), 경도(X) 벡터 생성
latVector = linspace(latLim(1), latLim(2), gridSize);
lonVector = linspace(lonLim(1), lonLim(2), gridSize);

%% [Step 1] 송신기 좌표를 격자 인덱스(Pixel)로 변환
% 전체 격자 중에서 송신기 실제 위치와 가장 가까운 점을 찾습니다.

% 행(Row) 인덱스 찾기 (위도 Y축)
[minDistLat, txRow] = min(abs(latVector - bsPositions(1)));

% 열(Col) 인덱스 찾기 (경도 X축)
[minDistLon, txCol] = min(abs(lonVector - bsPositions(2)));

fprintf('송신기 위치 변환 완료: (%d, %d)\n', txRow, txCol);
fprintf('오차 거리: 위도 %.2e, 경도 %.2e\n', minDistLat, minDistLon);

%% [Step 2] Tx Map 이미지 생성
% 검은 배경(0)에 송신기 위치만 흰색(1)으로 찍습니다.
txMap = zeros(gridSize, gridSize);
txMap(txRow, txCol) = 1;

% (선택사항) 점을 좀 더 크게 보고 싶다면 아래 주석 해제 (3x3 크기)
% txMap(max(1,txRow-1):min(gridSize,txRow+1), max(1,txCol-1):min(gridSize,txCol+1)) = 1;

%% [Step 3] 시각화 및 이미지 파일 저장
% 첨부하신 이미지처럼 깔끔하게 저장하기 위한 설정입니다.

f = figure('Visible', 'off'); % 창을 띄우지 않고 백그라운드에서 처리
imagesc(txMap);
colormap(gray); % 0=검정, 1=흰색
axis xy;        % Y축 방향 상하 반전 방지 (지도 좌표계 유지)
axis off;       % 축, 눈금 제거
axis equal;     % 가로세로 비율 유지

% 여백 없이 꽉 채우기 (이미지 저장 시 중요)
set(gca, 'Position', [0 0 1 1], 'Units', 'normalized');
set(gcf, 'PaperPositionMode', 'auto'); 

% 1. 이미지 파일로 저장 (PNG)
exportgraphics(gca, 'tx_location_map.png', 'Resolution', 300); % 해상도 조절 가능

% 2. 학습용 데이터 파일로 저장 (MAT)
save('tx_map.mat', 'txMap');

fprintf('저장 완료:\n 1. 이미지: tx_location_map.png\n 2. 데이터: tx_map.mat\n');

% 결과 확인용 창 띄우기
figure;
imagesc(txMap);
colormap(gray);
axis xy; axis equal;
title(sprintf('Generated Tx Map (at %d, %d)', txRow, txCol));