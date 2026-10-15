%% =========================
%  Clean Multi-UE CDL Script (2 BS)
% =========================
fc = 6e9;

% --- BS 2개 위치/방향 ---
bsPositions = [ 37.4555736 127.1329074   % BS1
                37.4552000 127.1342000]; % BS2
bsArrayOrient = [ -50  0;                % [az el] for BS1
                  130  0];               % [az el] for BS2
nBS = size(bsPositions,1);

bsAntSize = [8 8];
uePositions = [ 37.4555000 127.1338000   % UE1
                37.4556000 127.1333000]; % UE2
nUE = size(uePositions,1);

ueAntSize = [2 2];
ueArrayOrientation = [270 90].';
reflectionsOrder = 1;
SCS = 15; NRB = 52;

%% Site Viewer & Sites
if exist('viewer','var') && isvalid(viewer)
    clearMap(viewer);
else
    viewer = siteviewer("Basemap","openstreetmap","Buildings","seongnam.osm");
end


% 첫 원소로 사전할당
bsSites(1) = txsite("Name","BS1", ...
    "Latitude",  bsPositions(1,1), ...
    "Longitude", bsPositions(1,2), ...
    "AntennaAngle", bsArrayOrient(1,1:2), ...
    "AntennaHeight", 4, ...
    "TransmitterFrequency", fc);

% 나머지 채우기
for b = 2:nBS
    bsSites(b) = txsite("Name",sprintf("BS%d",b), ...
        "Latitude",  bsPositions(b,1), ...
        "Longitude", bsPositions(b,2), ...
        "AntennaAngle", bsArrayOrient(b,1:2), ...
        "AntennaHeight", 4, ...
        "TransmitterFrequency", fc);
end

% ---- UE도 같은 방식 권장 ----
nUE = size(uePositions,1);

ueSites(1) = rxsite("Name","UE1", ...
    "Latitude", uePositions(1,1), ...
    "Longitude", uePositions(1,2), ...
    "AntennaHeight", 1, ...
    "AntennaAngle", ueArrayOrientation(1:2));

for i = 2:nUE
    ueSites(i) = rxsite("Name",sprintf("UE%d",i), ...
        "Latitude", uePositions(i,1), ...
        "Longitude", uePositions(i,2), ...
        "AntennaHeight", 1, ...
        "AntennaAngle", ueArrayOrientation(1:2));
end

show(bsSites); show(ueSites);

%% Arrays & Channel Template
c = physconst('LightSpeed'); lambda = c/fc;
ueArray = phased.NRRectangularPanelArray('Size',[ueAntSize(1:2) 1 1], ...
    'Spacing',[0.5*lambda*[1 1] 1 1]); ueArray.ElementSet = {phased.IsotropicAntennaElement};
bsArray = phased.NRRectangularPanelArray('Size',[bsAntSize(1:2) 1 1], ...
    'Spacing',[0.5*lambda*[1 1] 1 1]); bsArray.ElementSet = {phased.NRAntennaElement};

ofdmInfo = nrOFDMInfo(NRB,SCS);
template = nrCDLChannel;
template.DelayProfile = 'Custom';
template.CarrierFrequency = fc;
template.NormalizeChannelOutputs = false;
template.NormalizePathGains = false;
template.ReceiveAntennaArray = ueArray;
template.ReceiveArrayOrientation = [ueArrayOrientation(1); -ueArrayOrientation(2); 0];
template.TransmitAntennaArray = bsArray;
% BS별로 다른 각도를 쓰므로 아래에서 ch마다 설정
template.SampleRate = ofdmInfo.SampleRate;
template.ChannelFiltering = false;

%% Ray Tracing (nBS x nUE)
pm = propagationModel("raytracing","Method","sbr", ...
    "MaxNumReflections",reflectionsOrder,"MaxNumDiffractions",0);
raysAll = raytrace(bsSites, ueSites, pm, "Type","pathloss"); % {nBS x nUE}

% Site Viewer에 레이 오버레이
for b = 1:nBS
    for i = 1:nUE
        if isempty(raysAll{b,i}), continue; end
        for k = 1:numel(raysAll{b,i}), plot(raysAll{b,i}(k)); end
    end
end

%% Per-BS, Per-UE: 채널/플롯/패턴
for b = 1:nBS
  for i = 1:nUE
    if isempty(raysAll{b,i})
        fprintf("[BS%d-UE%d] Rays: 0 (skip)\n", b,i); continue;
    end
    rays = raysAll{b,i};

    % Ray -> CDL
    toas   = [rays.PropagationDelay] - min([rays.PropagationDelay]);
    avgG   = -[rays.PathLoss];
    AoD    = [rays.AngleOfDeparture];   % [2 x L]: az;el
    AoA    = [rays.AngleOfArrival];
    isLOS  = any([rays.LineOfSight]);

    ch = clone(template);
    ch.AnglesAoD = AoD(1,:);    ch.AnglesZoD = 90 - AoD(2,:);
    ch.AnglesAoA = AoA(1,:);    ch.AnglesZoA = 90 - AoA(2,:);
    ch.PathDelays = toas;       ch.AveragePathGains = avgG;
    ch.HasLOSCluster = isLOS;
    % BS b의 배열 방향 적용
    ch.TransmitArrayOrientation = [bsArrayOrient(b,1); -bsArrayOrient(b,2); 0];

    % 채널 & 추정
    [pathGains, tS] = ch();
    pg = permute(pathGains,[2 1 3 4]);
    if isLOS && size(pg,1)>=2, pg = [sum(pg(1:2,:,:,:)); pg(3:end,:,:,:)]; end
    instPG = pow2db(abs(pg(:,1,1,1)).^2);

    pF = getPathFilters(ch);
    [off,~] = nrPerfectTimingEstimate(pathGains,pF);
    hest = nrPerfectChannelEstimate(pathGains,pF,NRB,SCS,0,off,tS);
    H2dB = pow2db(abs(hest(:,:,1,1)).^2);

    % ---- 플롯 (타이틀에 BS 표시) ----
    fig1 = figure('Name',sprintf('BS%d-UE%d Path Gains',b,i),'Color','k');
    ax1 = axes(fig1); hold(ax1,'on'); grid(ax1,'on');
    plot(ax1,instPG,'o-','DisplayName','Instantaneous (1^{st} tx - 1^{st} rx)');
    plot(ax1,avgG,'x--','DisplayName','Average (from ray tracing)');
    xlabel(ax1,'Path number'); ylabel(ax1,'Gain (dB)');
    title(ax1,sprintf('BS%d-UE%d Path gains',b,i)); legend(ax1,'Location','best'); stylizeAxesDark(ax1);

    fig2 = figure('Name',sprintf('BS%d-UE%d Channel Mag',b,i),'Color','k');
    ax2 = axes(fig2); surf(ax2,H2dB,'EdgeColor','none'); shading(ax2,'flat'); view(ax2,45,25);
    colormap(ax2,parula); colorbar(ax2); caxis(ax2,[prctile(H2dB(:),5), prctile(H2dB(:),95)]);
    xlabel(ax2,'Subcarriers'); ylabel(ax2,'OFDM Symbols'); zlabel(ax2,'Magnitude Squared (dB)');
    title(ax2,sprintf('Channel Magnitude Response (BS%d-UE%d, 1^{st} tx-1^{st} rx)',b,i)); stylizeAxesDark(ax2);

    % ---- 빔포밍 & 패턴 (옵션) ----
    [wbs,wue] = getBeamformingWeights(hest,1,0,1);
    if numel(wue)==prod(ueAntSize) || isscalar(wue)
        ueSites(i).Antenna = clone(ueArray); ueSites(i).Antenna.Taper = wue(:).';
        pattern(ueSites(i),fc,"Size",4); title(sprintf("UE%d Pattern (from BS%d)",i,b));
    end
    if numel(wbs)==prod(bsAntSize) || isscalar(wbs)
        bsSites(b).Antenna = clone(bsArray); bsSites(b).Antenna.Taper = wbs(:).';
        % pattern(bsSites(b),fc,"Size",5); % 필요 시 주석 해제
    end
  end
end

%% ===== Helpers =====
function stylizeAxesDark(ax)
    set(ax,'Color','k','XColor','w','YColor','w','ZColor','w', ...
        'GridColor',[0.5 0.5 0.5],'MinorGridColor',[0.3 0.3 0.3], ...
        'LineWidth',1.0,'Box','on');
    ax.FontName='Helvetica'; ax.FontSize=12;
    if ~isempty(ax.Title),ax.Title.Color='w';end
    if ~isempty(ax.XLabel),ax.XLabel.Color='w';end
    if ~isempty(ax.YLabel),ax.YLabel.Color='w';end
    if ~isempty(ax.ZLabel),ax.ZLabel.Color='w';end
    cb=findobj(ax.Parent,'Type','ColorBar'); if ~isempty(cb), set(cb,'Color','w'); end
end

function [wtx,wrx,D] = getBeamformingWeights(hEst,nLayers,scOffset,noRBs)
    [~,~,R,P] = size(hEst); scNo = scOffset+1;
    H = permute(mean(reshape(hEst(scNo:scNo+(12*noRBs-1),:,:,:),[],R,P)),[2 3 1]);
    [U,D,V] = svd(H); wtx = V(:,1:nLayers).'; wrx = U(:,1:nLayers)';
end