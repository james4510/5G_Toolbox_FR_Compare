# 5G_Toolbox_FR_Compare

MATLAB 5G Toolbox + Ray Tracing으로 FR1(4.7 GHz)과 FR2(28 GHz) 5G 특화망 커버리지를 비교한 코드 모음.
가천대 글로벌캠퍼스(성남시 수정구) 일대를 OSM 건물 데이터로 모델링해서 시뮬레이션함.

## 구조

```
setup.m                        경로 등록용. 실행 전 한 번 돌릴 것
scripts/
  01_cdl_tutorials/            nrCDLChannel, ray tracing 연습 코드
  02_fr1_fr2_comparison/       FR1 vs FR2 히트맵, UE 배치, 커버리지 비교
  03_urban_ray_tracing/        Urban link & coverage 분석, 음영지역 예측
  04_radiomap_dataset/         딥러닝용 256x256 radio map 생성
data/osm/                      OSM 건물 데이터
results/
  fr1_fr2_comparison/          02 결과 (figures, csv)
  urban_ray_tracing/           03 결과
  radiomap_dataset/            04 결과
```

## 실행

- MATLAB에서 저장소 루트를 연 다음 `setup` 실행. scripts/, data/ 하위 폴더가 path에 추가됨
- 스크립트는 OSM 파일을 이름으로만 부르기 때문에 (`siteviewer(Buildings="seongnam.osm")`) path 등록이 안 되어 있으면 지도 로딩에서 실패함
- 결과 파일(png, pdf, csv, mat)은 현재 폴더에 떨어짐. 기존 결과 옆에 두려면 해당 results 폴더로 cd 하고 나서 실행

필요 툴박스

- MATLAB R2025a
- 5G Toolbox, Communications Toolbox, Antenna Toolbox, Phased Array System Toolbox
- Wireless Network Simulation Library: NR_Intercell_Tutorial_1.m 에서만 사용
- GPU 가속은 선택. Accelerate_Ray_Tracing_Analysis_Using_GPU.m 으로 GPU 인식 여부만 확인

## 스크립트

### 01_cdl_tutorials

- CDL_Tutorial.m : BS 1개, UE 여러 개 nrCDLChannel 기본 예제 (6 GHz)
- CDL_Tut_2.m : BS 2개 버전
- CDL_ex_1_1.m, CDL_ex_1_2.m, CDL_ex_2.m : MathWorks CDL 예제를 성남 지도로 바꿔서 돌려본 것
- CDL_freq.m : 28 GHz에서 CDL 채널 응답 확인
- CDL_Code.m : BS 1개 기준 최소 수신감도(-95 dBm) 기준 가용성 분석 초안
- Interactive_CDL_Channel_Model_Configuration.m : CDL 설정 앱 실행
- NR_Intercell_Tutorial_1.m : wirelessNetworkSimulator로 gNB 3개 셀간 간섭 튜토리얼

### 02_fr1_fr2_comparison

이 저장소의 본 실험. 시기 순서대로 발전시킨 거라 뒤쪽 파일일수록 최신 버전.

- CDL_FR1_FR2_compare.m : 영역 전체 히트맵(SNR, Rx power, throughput) + 대표 포인트 6개 비교
  - 출력: Heatmap_*.png, *_bar.png, results_FR1_FR2_*.csv
- CDL_FR1_FR2_compare_code.m : 위 내용에 FR2 추가 기지국 수 계산, 거리별 성능 저하, 군용 요구사항 분석 추가
  - 출력: BS_Optimization_Analysis.png, Military_*.png, results_BS_optimization.csv, results_military_requirements.csv
- CDL_FR1_FR2_Wifi_compare_code.m : FR1 / FR2 / Wi-Fi 5 GHz 세 가지 비교. 드론 원격제어 시나리오로 군용 적용 가능성 검토
  - 출력: BS_Density.png, military_evaluation_results.csv
- CDL_FR_analysis.m : BS 중심 히트맵 + 실제 위경도 좌표로 UE 배치
  - 출력: SNR/Throughput/RxPower_Heatmap_*_GHz.png/pdf, UE_Deployment_Pattern.png, ue_coordinates.csv
- CDL_FR_compare_analysis.m : CDL_FR_analysis.m 개선판. UE를 일정 각도 간격으로 배치하고 figure는 백그라운드에서 생성
- CDL_FR_compare_code.m : 히트맵 빼고 실제 UE 위치만 보는 가벼운 버전
- CDL_FR_compare_test.m : UE 위치 분석 + TDD 설정 비교, DL/UL throughput 맵
  - 출력: UE_DL_Throughput_Map_*.png, UE_UL_Throughput_Map_*.png, TDD_Configuration_Comparison.png, results_TDD_*.csv
- CDL_FR_compare.m : UE 한 점에 대한 FR1 채널 응답만 확인하는 최소 예제

### 03_urban_ray_tracing

- Urban_Link_and_Coverage_Analysis_Using_Ray_Tracing.m : MathWorks 예제 기반 NLOS 링크 분석, SBR 커버리지 시각화
- Urban_Link_and_Coverage_Analysis_Using_Ray_Tracing2.m : BS-UE 거리 계산, 거리별 신호세기 분석 추가
  - 출력: signal_strength_analysis.csv, UE_Signal_Strength.png, Distance_vs_Power.png
- Urban_Link_and_Coverage.m : TX 2개(4.7 / 28 GHz)에 같은 링크 실험 반복
- Urban_Link.m : 가천대 AI공학관 위치에 송신국 고정하고 링크 분석
- NR_FR_analysis.m : 방향성 패널 안테나(FR1 8x8, FR2 16x16)로 FR1/FR2 커버리지 분석
- NR_FR_analysis2.m : SNR, SINR 계산 보정 버전
- NR_FR_analysis_fix.m : BS 2개(가천대, 서울공항) 시나리오
- NR_FR_Comparative_analysis.m : 송신전력 FR1 60 W / FR2 2 W 로 두고 RX 빔포밍 이득까지 반영한 비교
- NR_FR_Comparative_analysis_v1.m : 위 파일 이전 버전. RX 빔포밍 이득 없음
- NR_FR_analysis_ray_tracing.m : 음영지역 예측용 ground truth 생성
  - 출력: 5G_Coverage_Analysis_<timestamp>.mat/csv/png/fig
- Ray_Tracing.m, Ray_Tracing_Test.m : 반사 차수, 기지국 시나리오 바꿔가며 coverage 테스트
- Accelerate_Ray_Tracing_Analysis_Using_GPU.m : gpuDevice 확인

### 04_radiomap_dataset

500 m x 500 m 영역을 256x256 격자로 잘라서 건물 마스크, 송신기 위치, 수신전력 맵을 만듦.
세 스크립트의 Step 0 설정(bsPositions, gridSize, mapWidthMeters)이 서로 같아야 격자가 맞음.

- make_building_mask.m : OSM 파싱해서 건물 polygon을 격자에 래스터화. building_map_mask.mat
- make_tx_map.m : 송신기 좌표를 격자 픽셀로 변환. tx_map.mat, tx_location_map.png
- make_coverage_map.m : coverage() 결과를 격자로 변환한 수신전력 맵. coverage_map_fast.mat, coverage_only_clean.png
- coverage_power_map_plot.m : 커버리지 결과를 imagesc로 논문 그림 스타일로 출력
- OutdoorRayTracingCoverageMap.m : 커버리지 맵 생성 초기 버전. result_matrix.mat
- OutdoorRayTracingDistanceMap.m : 송신기까지 거리 맵. distance_map.mat
- OutdoorRayTracingExample*.m : siteviewer + ray tracing coverage 기본 예제

results/radiomap_dataset/dataset_lat*_lon*.mat 는 송신기 위치 세 곳에 대해 뽑은 데이터셋.

## 데이터

- seongnam.osm, seongnam_map.osm : 성남시. 대부분의 스크립트가 이 둘 중 하나를 씀
- gachon_univ_map.osm, gachon_mangkeong.osm : 가천대 캠퍼스
- gapyeong.osm, seoraksan.osm, taebaeksan.osm : 산악 지형 비교용

## 메모

- 처음엔 전부 루트에 올라가 있던 걸 위 구조로 옮김. 코드 자체는 OSM 파일명 외에 손대지 않음
- 5G_NR_FR_analysis.m, NR_FR_analysis_.m 은 NR_FR_analysis.m 과 내용이 같아서 삭제
- untitled*.m 은 역할대로 이름 변경. NR_FR_Comparative_analyss.m 은 오타라서 _v1 으로 변경
- *.asv 는 지우고 .gitignore 에 추가. 필요하면 git 이력에서 꺼낼 수 있음
