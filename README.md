# 5G_Toolbox_FR_Compare

MATLAB 5G Toolbox + Ray Tracing 기반 FR1(4.7 GHz) vs FR2(28 GHz) 커버리지 비교.
대상 지역: 가천대 글로벌캠퍼스 (OSM 건물 데이터 사용)

## 환경

- MATLAB R2025a
- 5G Toolbox, Communications Toolbox, Antenna Toolbox, Phased Array System Toolbox

## 실행

```matlab
setup                 % scripts/, data/ path 등록
cd results/fr1_fr2_comparison
CDL_FR_analysis       % 예시
```

- 결과 파일은 현재 폴더에 저장됨
- OSM 파일은 이름으로만 참조하므로 setup 없이 실행하면 지도 로딩 실패

## 구조

```
scripts/
  01_cdl_tutorials/          CDL 채널 연습 코드
  02_fr1_fr2_comparison/     FR1 vs FR2 비교 (본 실험)
  03_urban_ray_tracing/      Urban link & coverage, 음영지역 예측
  04_radiomap_dataset/       딥러닝용 256x256 radio map 생성
data/osm/                    OSM 건물 데이터
results/                     scripts 폴더별 결과물 (png, pdf, csv, mat)
```

## 핵심 스크립트

02_fr1_fr2_comparison

- CDL_FR1_FR2_compare.m : 영역 히트맵(SNR, Rx power, throughput) + 대표 포인트 6개
- CDL_FR1_FR2_compare_code.m : + FR2 추가 기지국 수, 거리별 성능 저하, 군용 요구사항
- CDL_FR1_FR2_Wifi_compare_code.m : FR1 / FR2 / Wi-Fi 5 GHz 비교
- CDL_FR_compare_analysis.m : 실제 좌표 UE 배치 버전 (최신)
- CDL_FR_compare_test.m : UE 위치 분석 + TDD 설정 비교

03_urban_ray_tracing

- NR_FR_Comparative_analysis.m : 송신전력 FR1 60 W / FR2 2 W, RX 빔포밍 반영 비교
- NR_FR_analysis_ray_tracing.m : 음영지역 예측 ground truth 생성
- Urban_Link_and_Coverage_Analysis_Using_Ray_Tracing2.m : BS-UE 거리별 신호세기

04_radiomap_dataset

- make_building_mask.m : 건물 마스크 (building_map_mask.mat)
- make_tx_map.m : 송신기 위치 맵 (tx_map.mat)
- make_coverage_map.m : 수신전력 맵 (coverage_map_fast.mat)
- 세 파일의 Step 0 설정값(bsPositions, gridSize, mapWidthMeters)은 동일하게 유지

## 데이터

- seongnam.osm, seongnam_map.osm : 성남시 (주 사용)
- gachon_*.osm : 가천대 캠퍼스
- gapyeong, seoraksan, taebaeksan.osm : 산악 지형 비교용
