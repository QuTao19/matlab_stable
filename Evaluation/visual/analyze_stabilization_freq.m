function [reduction_dB, high_freq_energy_ratio] = analyze_stabilization_freq(traj_orig, traj_stab, fps, cutoff_freq)
% ANALYZE_STABILIZATION_FREQ 分析防抖前后的频域特性
%
% 输入:
%   traj_orig   : 原始视频的轨迹向量 (1D array, 比如 X 轴位移)
%   traj_stab   : 防抖后视频的轨迹向量 (1D array)
%   fps         : 视频帧率 (Frames Per Second)
%   cutoff_freq : (可选) 定义抖动的高频截止频率，默认 2Hz
%
% 输出:
%   reduction_dB : 高频能量衰减分贝数 (dB)。正值越大效果越好。
%   high_freq_energy_ratio : 高频能量比值 (原/后)
%
% 示例:
%   db = analyze_stabilization_freq(orig_x, stab_x, 30, 2);

    % --- 0. 参数校验与预处理 ---
    if nargin < 4
        cutoff_freq = 2.0; % 默认 2Hz 以上算抖动
    end
    
    % 确保输入是列向量
    traj_orig = traj_orig(:);
    traj_stab = traj_stab(:);
    
    % 长度对齐 (以短的为准)
    min_len = min(length(traj_orig), length(traj_stab));
    traj_orig = traj_orig(1:min_len);
    traj_stab = traj_stab(1:min_len);
    
    L = min_len;             % 信号长度
    t = (0:L-1) / fps;       % 时间轴
    
    % 消除直流分量 (Detrend) 以便更好地观察波动，而非绝对位置
    % 注意：如果不希望消除整体位移趋势，可注释掉下面两行
    sig_orig = detrend(traj_orig);
    sig_stab = detrend(traj_stab);
    
    % --- 1. FFT 变换 ---
    Y_orig = fft(sig_orig);
    Y_stab = fft(sig_stab);
    
    % 计算单侧频谱 (Single-Sided Spectrum)
    P2_orig = abs(Y_orig / L);
    P1_orig = P2_orig(1:floor(L/2)+1);
    P1_orig(2:end-1) = 2*P1_orig(2:end-1);
    
    P2_stab = abs(Y_stab / L);
    P1_stab = P2_stab(1:floor(L/2)+1);
    P1_stab(2:end-1) = 2*P1_stab(2:end-1);
    
    f = fps * (0:floor(L/2)) / L; % 频率轴
    
    % --- 2. 计算指标 ---
    % 找到高频部分的索引
    idx_high = find(f >= cutoff_freq);
    
    if isempty(idx_high)
        warning('截止频率设置过高或视频过短，无法计算高频分量。');
        reduction_dB = 0;
        high_freq_energy_ratio = 1;
    else
        % 计算高频频段的总能量 (平方和)
        energy_orig_high = sum(P1_orig(idx_high).^2);
        energy_stab_high = sum(P1_stab(idx_high).^2);
        
        % 防止除以0
        if energy_stab_high < 1e-10
            energy_stab_high = 1e-10; 
        end
        
        high_freq_energy_ratio = energy_orig_high / energy_stab_high;
        reduction_dB = 10 * log10(high_freq_energy_ratio);
    end
    
    % --- 3. 绘图可视化 ---
    figure('Name', 'Stabilization Frequency Analysis', 'Color', 'w');
    
    % 子图1：时域波形
    subplot(2,1,1);
    plot(t, traj_orig, 'r', 'LineWidth', 1); hold on;
    plot(t, traj_stab, 'g', 'LineWidth', 1.5);
    title(['时域轨迹对比 (Time Domain) - L = ' num2str(L) ' frames']);
    xlabel('Time (s)'); ylabel('Amplitude / Pixel');
    legend('Original', 'Stabilized');
    grid on; axis tight;
    
    % 子图2：频域谱
    subplot(2,1,2);
    semilogy(f, P1_orig, 'r', 'LineWidth', 1); hold on;
    semilogy(f, P1_stab, 'g', 'LineWidth', 1.5);
    
    % 画截止频率线
    xline(cutoff_freq, '--b', sprintf('Cutoff %.1f Hz', cutoff_freq), 'LineWidth', 1.5);
    
    title(sprintf('频域幅度谱 (Frequency Domain) | 高频抑制: %.2f dB', reduction_dB));
    xlabel('Frequency (Hz)'); ylabel('Magnitude (Log Scale)');
    legend('Original Spectrum', 'Stabilized Spectrum');
    grid on; 
    xlim([0, fps/2]); % 只显示到奈奎斯特频率
end