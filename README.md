# 5G Toolbox FR1 / FR2 Comparison

MATLAB 5G Toolbox와 Ray Tracing(Communications / Antenna Toolbox)을 이용해
**FR1(4.7 GHz)과 FR2(28 GHz) 5G 특화망의 커버리지·성능을 비교**한 실험 코드와 결과물 모음입니다.
실험 지역은 가천대학교 글로벌캠퍼스(경기 성남시 수정구)이며, OpenStreetMap 건물 데이터를 기반으로 시뮬레이션합니다.

## 폴더 구조

```
.
├── setup.m                      # MATLAB 경로 설정 (실행 전 1회)
├── scripts/
│   ├── 01_cdl_tutorials/        # nrCDLChannel / Ray Tracing 기초 튜토리얼
│   ├── 02_fr1_fr2_comparison/   # FR1 vs FR2 히트맵·UE 배치·커버리지 비교 (메인 실험)
│   ├── 03_urban_ray_tracing/    # Urban Link & Coverage 분석, 음영 지역 예측
│   └── 04_radiomap_dataset/     # 딥러닝용 256x256 radio map 데이터셋 생성
├── data/
│   └── osm/                     # OpenStreetMap 건물 데이터 (.osm)
└── results/
    ├── fr1_fr2_comparison/      # 02 스크립트 결과 (figures/, csv/)
    ├── urban_ray_tracing/       # 03 스크립트 결과
    └── radiomap_dataset/        # 04 스크립트 결과 (.mat, .png)
```

## 실행 방법

1. MATLAB에서 저장소 루트 폴더를 연 뒤 경로를 등록합니다.

   ```matlab
   setup
   ```

2. 원하는 스크립트를 실행합니다. 예:

   ```matlab
   CDL_FR_analysis          % FR1 vs FR2 히트맵 + 실제 좌표 UE 배치 분석
   ```

   결과 파일(PNG/PDF/CSV/MAT)은 **현재 작업 폴더**에 저장됩니다. 기존 결과와 같은 위치에 저장하려면
   먼저 `cd results/fr1_fr2_comparison` 등으로 이동한 뒤 실행하세요.

### 요구 사항

- MATLAB R2025a
- 5G Toolbox, Communications Toolbox, Antenna Toolbox(Site Viewer / Ray Tracing), Phased Array System Toolbox
- Wireless Network Simulation Library (`NR_Intercell_Tutorial_1.m` 전용)
- Parallel Computing Toolbox + GPU (선택, `Accelerate_Ray_Tracing_Analysis_Using_GPU.m`)

## 스크립트 설명

### 01_cdl_tutorials — CDL 채널 / Ray Tracing 기초

| 파일 | 내용 |
|---|---|
| `CDL_Tutorial.m` | 단일 BS, 다중 UE에 대한 `nrCDLChannel` 기본 예제 (6 GHz) |
| `CDL_Tut_2.m` | BS 2개 + 다중 UE 버전 |
| `CDL_ex_1_1.m`, `CDL_ex_1_2.m`, `CDL_ex_2.m` | MathWorks CDL 예제를 성남 지도에 맞게 수정한 연습 코드 |
| `CDL_freq.m` | 주파수(28 GHz)별 CDL 채널 응답 확인 |
| `CDL_Code.m` | 단일 BS 기준 네트워크 가용성(최소 수신 감도) 분석 초안 |
| `Interactive_CDL_Channel_Model_Configuration.m` | CDL 채널 모델 설정 앱 실행 |
| `NR_Intercell_Tutorial_1.m` | `wirelessNetworkSimulator` 기반 3-gNB 셀 간 간섭 튜토리얼 |

### 02_fr1_fr2_comparison — FR1 vs FR2 비교 (메인 실험)

| 파일 | 내용 | 주요 출력 |
|---|---|---|
| `CDL_FR1_FR2_compare.m` | 전체 영역 히트맵(SNR/Rx Power/Throughput) + 대표 포인트 6개 비교 | `Heatmap_*`, `*_bar.png`, `results_FR1_FR2_*.csv` |
| `CDL_FR1_FR2_compare_code.m` | 위 분석 + FR2 추가 기지국 수 계산, 거리별 성능 저하, 군사용 요구사항 분석 | `BS_Optimization_Analysis.png`, `Military_*`, `results_BS_optimization.csv` |
| `CDL_FR1_FR2_Wifi_compare_code.m` | FR1 / FR2 / Wi-Fi(5 GHz) 성능 비교 및 군사용 적용 가능성(드론 제어 시나리오) | `BS_Density.png`, `military_evaluation_results.csv` |
| `CDL_FR_analysis.m` | BS 중심 동적 히트맵 + 실제 위경도 좌표 기반 UE 배치 및 시각화 | `*_Heatmap_*_GHz.png/pdf`, `UE_Deployment_Pattern.png`, `ue_coordinates.csv` |
| `CDL_FR_compare_analysis.m` | `CDL_FR_analysis.m` 개선판 — 각도 간격 UE 배치, 백그라운드 figure 생성 | 위와 동일 |
| `CDL_FR_compare_code.m` | 히트맵 없이 실제 UE 위치만 분석하는 경량 버전 | `UE_Deployment_Pattern.png` |
| `CDL_FR_compare_test.m` | UE 위치 분석 + TDD 구성 비교, DL/UL Throughput 맵 | `UE_DL/UL_Throughput_Map_*`, `TDD_*`, `results_TDD_*.csv` |
| `CDL_FR_compare.m` | 단일 UE 포인트에 대한 FR1 채널 응답 확인용 최소 예제 | - |

### 03_urban_ray_tracing — Urban Link & Coverage 분석

| 파일 | 내용 | 주요 출력 |
|---|---|---|
| `Urban_Link_and_Coverage_Analysis_Using_Ray_Tracing.m` | MathWorks 예제 기반 NLOS 링크 분석 및 SBR 커버리지 시각화 | - |
| `Urban_Link_and_Coverage_Analysis_Using_Ray_Tracing2.m` | BS–UE 거리 계산, 거리별 신호 세기 분석 추가 | `signal_strength_analysis.csv`, `UE_Signal_Strength.png`, `Distance_vs_Power.png` |
| `Urban_Link_and_Coverage.m` | TX 2개(4.7 GHz / 28 GHz)에 대해 동일 링크 실험 반복 | - |
| `Urban_Link.m` | 가천대 AI공학관 위치 고정 송신국 기준 링크 분석 | - |
| `NR_FR_analysis.m` | 방향성 안테나(8x8 / 16x16 패널) 기반 FR1·FR2 커버리지 분석 | - |
| `NR_FR_analysis2.m` | SNR / SINR 계산 보정 버전 | - |
| `NR_FR_analysis_fix.m` | BS 2개(가천대, 서울공항) 시나리오 | - |
| `NR_FR_Comparative_analysis.m` | 현실적 송신 전력(FR1 60 W / FR2 2 W) + RX 빔포밍 이득 반영 비교 | - |
| `NR_FR_Comparative_analysis_v1.m` | 위 스크립트의 이전 버전(RX 빔포밍 이득 미반영) | - |
| `NR_FR_analysis_ray_tracing.m` | 5G 음영 지역 예측 — ground truth 저장 | `5G_Coverage_Analysis_<timestamp>.*` |
| `Ray_Tracing.m`, `Ray_Tracing_Test.m` | 반사 차수 / 기지국 시나리오별 Ray Tracing 커버리지 테스트 | - |
| `Accelerate_Ray_Tracing_Analysis_Using_GPU.m` | GPU 사용 가능 여부 확인 | - |

### 04_radiomap_dataset — 딥러닝용 Radio Map 데이터셋 생성

256×256 격자(500 m × 500 m)로 건물 마스크 / 송신기 위치 / 커버리지(수신 전력) 맵을 생성합니다.
세 스크립트의 `[Step 0]` 초기 설정(송신기 위치, 격자 크기)은 반드시 동일하게 유지해야 합니다.

| 파일 | 내용 | 출력 |
|---|---|---|
| `make_building_mask.m` | OSM 파일을 파싱해 건물 영역을 격자에 래스터화 | `building_map_mask.mat` |
| `make_tx_map.m` | 송신기 좌표를 격자 픽셀로 변환한 Tx 맵 | `tx_map.mat`, `tx_location_map.png` |
| `make_coverage_map.m` | Ray Tracing `coverage` 결과를 격자로 변환한 수신 전력 맵 | `coverage_map_fast.mat`, `coverage_only_clean.png` |
| `coverage_power_map_plot.m` | 커버리지 결과를 논문 스타일 히트맵(`imagesc`)으로 시각화 | - |
| `OutdoorRayTracingCoverageMap.m` | 커버리지 맵 생성 초기 버전 | `result_matrix.mat` |
| `OutdoorRayTracingDistanceMap.m` | 송신기까지의 거리 맵 생성 | `distance_map.mat` |
| `OutdoorRayTracingExample*.m` | Site Viewer + Ray Tracing 커버리지 기본 예제 |- |

`results/radiomap_dataset/dataset_lat*_lon*.mat`는 세 지점(송신기 위치)에 대해 생성된 데이터셋입니다.

## 데이터 (`data/osm`)

| 파일 | 지역 |
|---|---|
| `seongnam.osm`, `seongnam_map.osm` | 성남시 (가천대 주변 포함) — 대부분의 스크립트가 사용 |
| `gachon_univ_map.osm`, `gachon_mangkeong.osm` | 가천대 캠퍼스 |
| `gapyeong.osm`, `seoraksan.osm`, `taebaeksan.osm` | 산악 지형 비교용 |

> **참고:** 스크립트들은 `seongnam.osm` 또는 `seongnam_map.osm`을 파일명으로만 참조하므로 `setup`으로 `data/osm`이 경로에 올라가 있어야 합니다.

## 정리 이력

- 이전 커밋에서 루트에 평면으로 올라가 있던 파일들을 위 구조로 재배치했습니다.
- 내용이 완전히 같던 `5G_NR_FR_analysis.m`, `NR_FR_analysis_.m`는 `NR_FR_analysis.m` 하나로 통합했습니다.
- `untitled*.m`은 역할에 맞는 이름으로, `NR_FR_Comparative_analyss.m`(오타)은 `NR_FR_Comparative_analysis_v1.m`으로 변경했습니다.
- MATLAB 자동 저장 파일(`*.asv`)은 삭제하고 `.gitignore`에 추가했습니다. 필요하면 git 이력에서 복구할 수 있습니다.
