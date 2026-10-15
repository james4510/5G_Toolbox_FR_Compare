%% Distance Map 생성

% 1. 맵 격자(Grid) 설정
gridSize = 256;         % 딥러닝 입력 이미지 크기 (256x256)
mapWidthMeters = 500;   % 맵의 실제 가로/세로 크기 (MaxRange=250이므로 지름 500m)

% 2. 미터(m) 단위를 위도/경도 단위로 변환
metersPerDegreeLat = 111000; % 위도 1도당 약 111km
metersPerDegreeLon = 111000 * cosd(bsPositions(1));

deltaLat = (mapWidthMeters / 2) / metersPerDegreeLat;
deltaLon = (mapWidthMeters / 2) / metersPerDegreeLon;

% 3. 맵의 범위(Boundary) 정의
latLim = [bsPositions(1) - deltaLat, bsPositions(1) + deltaLat];
lonLim = [bsPositions(2) - deltaLon, bsPositions(2) + deltaLon];

% 4. 격자 좌표 생성 (Meshgrid)
latVector = linspace(latLim(1), latLim(2), gridSize);
lonVector = linspace(lonLim(1), lonLim(2), gridSize);
[LON_GRID, LAT_GRID] = meshgrid(lonVector, latVector);

% 5. 유클리드 거리 계산 (Distance Map 핵심)
% 각 픽셀(Rx)과 송신기(Tx) 사이의 거리를 미터 단위로 계산
distY = (LAT_GRID - bsPositions(1)) * metersPerDegreeLat; % 위도 차이 -> 미터
distX = (LON_GRID - bsPositions(2)) * metersPerDegreeLon; % 경도 차이 -> 미터

% 피타고라스 정리로 거리 산출
distanceMap = sqrt(distX.^2 + distY.^2);

%% [결과 확인 및 저장]
figure('Name', 'Distance Map');

% 1. 시각화 (imagesc)
imagesc(distanceMap);
colorbar;
title('Distance Map (Meters)');
xlabel('Pixel X'); ylabel('Pixel Y');

% 맵 스타일 설정 (지도 좌표계 방향, 비율 고정)
axis xy; axis equal; axis tight;

% 2. 데이터 저장
save('distance_map.mat', 'distanceMap');
fprintf('Distance Map 생성 및 저장 완료: distance_map.mat (범위: 0 ~ %.2fm)\n', max(distanceMap(:)));