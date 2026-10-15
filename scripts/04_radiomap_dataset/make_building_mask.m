%% [Step 0] 초기 설정 (Power Map 생성 때와 완벽히 동일해야 함)
clear; clc;

osmFile = "seongnam_map.osm";
bsPositions = [37.4516, 127.1295]; % 송신기 위치
gridSize = 256;          % 저장할 이미지 해상도 (256x256)
mapWidthMeters = 500;    % 맵 크기 (500m)

% 격자(Grid) 생성 (Power Map과 좌표를 일치시키기 위함)
metersPerDegreeLat = 111000;
metersPerDegreeLon = 111000 * cosd(bsPositions(1));
deltaLat = (mapWidthMeters / 2) / metersPerDegreeLat;
deltaLon = (mapWidthMeters / 2) / metersPerDegreeLon;

latLim = [bsPositions(1) - deltaLat, bsPositions(1) + deltaLat];
lonLim = [bsPositions(2) - deltaLon, bsPositions(2) + deltaLon];

latVector = linspace(latLim(1), latLim(2), gridSize);
lonVector = linspace(lonLim(1), lonLim(2), gridSize);
[LON_GRID, LAT_GRID] = meshgrid(lonVector, latVector);

%% [Step 1] OSM 파일 파싱 (XML 읽기)
fprintf('OSM 파일 파싱 중... (건물 정보 추출)\n');

% XML 파일 읽기
xDoc = xmlread(osmFile);
osmNode = xDoc.getDocumentElement;

% 1. 모든 Node(점) 좌표 추출
nodeItems = osmNode.getElementsByTagName('node');
numNodes = nodeItems.getLength;

% 노드 ID와 좌표를 저장할 Map 생성 (검색 속도 향상)
nodeMapLat = containers.Map('KeyType', 'char', 'ValueType', 'double');
nodeMapLon = containers.Map('KeyType', 'char', 'ValueType', 'double');

for i = 0:numNodes-1
    item = nodeItems.item(i);
    id = char(item.getAttribute('id'));
    lat = str2double(item.getAttribute('lat'));
    lon = str2double(item.getAttribute('lon'));
    
    % 맵 범위 내에 있는 노드만 저장 (메모리 절약)
    if lat >= latLim(1)-0.001 && lat <= latLim(2)+0.001 && ...
       lon >= lonLim(1)-0.001 && lon <= lonLim(2)+0.001
        nodeMapLat(id) = lat;
        nodeMapLon(id) = lon;
    end
end

%% [Step 2] Building(면) 정보 추출 및 다각형(Polygon) 생성
wayItems = osmNode.getElementsByTagName('way');
numWays = wayItems.getLength;
buildingPolys = {}; % 건물 다각형 좌표 저장소

for i = 0:numWays-1
    way = wayItems.item(i);
    
    % 'building' 태그가 있는지 확인
    isBuilding = false;
    tags = way.getElementsByTagName('tag');
    for j = 0:tags.getLength-1
        tag = tags.item(j);
        if strcmp(tag.getAttribute('k'), 'building')
            isBuilding = true;
            break;
        end
    end
    
    if isBuilding
        % 이 건물을 구성하는 노드(점)들의 ID 가져오기
        ndRefs = way.getElementsByTagName('nd');
        bLat = [];
        bLon = [];
        validPoly = true;
        
        for k = 0:ndRefs.getLength-1
            ref = char(ndRefs.item(k).getAttribute('ref'));
            if isKey(nodeMapLat, ref)
                bLat(end+1) = nodeMapLat(ref);
                bLon(end+1) = nodeMapLon(ref);
            else
                % 맵 범위 밖의 노드를 참조하면 무시
                validPoly = false; 
                % break; % 부분적으로 걸친 건물도 그리기 위해 break 제거 가능
            end
        end
        
        if validPoly && ~isempty(bLat)
            buildingPolys{end+1} = [bLon', bLat']; % [x, y] 순서
        end
    end
end

%% [Step 3] 격자(Grid)에 건물 매핑 (Rasterization)
fprintf('건물 맵 생성 중... (Rasterization)\n');

% 0으로 초기화된 맵 (0: 빈 공간, 1: 건물)
buildingMap = zeros(gridSize, gridSize);

% 각 건물 다각형에 대해 격자 내부 포함 여부 확인 (inpolygon)
% *Tip: 루프가 많아 속도가 느리면 parallel pool 사용 가능
for i = 1:length(buildingPolys)
    poly = buildingPolys{i};
    polyLon = poly(:,1);
    polyLat = poly(:,2);
    
    % inpolygon 함수: 격자 점들이 다각형 안에 있는지 검사 (1=내부, 0=외부)
    in = inpolygon(LON_GRID, LAT_GRID, polyLon, polyLat);
    
    % 건물 부분 1로 마킹 (OR 연산으로 겹치는 건물 처리)
    buildingMap = buildingMap | in;
end

% 논리형을 숫자형으로 변환 (저장 편의성)
buildingMap = double(buildingMap);

%% [Step 4] 결과 확인 및 저장
figure(2);
imagesc(buildingMap); 
colormap(gray); % 흑백 (흰색: 건물, 검은색: 빈 공간)
colorbar;
title('Generated Building Map (Binary Mask)');
axis xy; axis equal;

% .mat 파일로 저장
save('building_map_mask.mat', 'buildingMap');
fprintf('건물 맵 저장 완료: building_map_mask.mat\n');