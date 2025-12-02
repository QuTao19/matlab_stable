%% 防抖数据可视化与报告生成
% 功能：弹出窗口选择单个文件，进行全维度分析并生成 PDF 报告
clear; clc; close all;

%% 1. 手动选择文件
% 默认打开当前目录或上次的目录
[file_name, file_path] = uigetfile('*.txt', '请选择轨迹数据文件 (.txt)');

% 检查用户是否取消了选择
if isequal(file_name, 0)
    disp('用户取消了操作。');
    return;
end

full_file_path = fullfile(file_path, file_name);
[~, name_body, ~] = fileparts(file_name);

fprintf('正在分析文件: %s\n', file_name);
fprintf('保存路径: %s\n', file_path);

%% 2. 全局配置
fps = 50;                 % 视频帧率 (影响频域分析坐标)
style.color1 = '#F36E43'; % 原始数据 (橙红)
style.color2 = '#4A64AE'; % 处理后 (蓝)
style.lw1 = 1;            
style.lw2 = 2;            

% 定义输出 PDF 文件名
pdf_report_name = fullfile(file_path, [name_body, '_report.pdf']);
% 删除旧的 PDF (如果存在)，防止追加到旧文件里
if isfile(pdf_report_name)
    delete(pdf_report_name);
end

try
    %% ==================================================
    %% 第一页：相对位移分析 (Relative / Jitter)
    %% ==================================================
    fprintf('Step 1: 计算相对位移 (Jitter)...\n');
    results = calc_trajectory_stats(full_file_path);
    
    fig1 = figure('Name', '相对位移分析', 'Color', 'white', 'Position', [100, 100, 1000, 800]);
    
    % X Axis
    subplot(3, 1, 1);
    plot(results.time_series, results.x.delta_orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
    plot(results.time_series, results.x.delta_smooth, 'Color', style.color2, 'LineWidth', style.lw2);
    title(['X Axis Jitter (Relative) - ' name_body], 'Interpreter', 'none');
    ylabel('Delta (px)'); legend('Original', 'Stabilized'); grid on; xlim([min(results.time_series) max(results.time_series)]);
    
    % Y Axis
    subplot(3, 1, 2);
    plot(results.time_series, results.y.delta_orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
    plot(results.time_series, results.y.delta_smooth, 'Color', style.color2, 'LineWidth', style.lw2);
    title('Y Axis Jitter (Relative)'); ylabel('Delta (px)'); grid on; xlim([min(results.time_series) max(results.time_series)]);
    
    % Rotation
    subplot(3, 1, 3);
    plot(results.time_series, results.rotation.delta_orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
    plot(results.time_series, results.rotation.delta_smooth, 'Color', style.color2, 'LineWidth', style.lw2);
    title('Rotation Jitter (Relative)'); ylabel('Delta (deg)'); grid on; xlim([min(results.time_series) max(results.time_series)]);
    
    % 保存
    exportgraphics(fig1, fullfile(file_path, [name_body, '_01_jitter.png']), 'Resolution', 150);
    exportgraphics(fig1, pdf_report_name, 'ContentType', 'vector'); % 创建 PDF
    
    %% ==================================================
    %% 第二页：绝对轨迹分析 (Absolute Trajectory)
    %% ==================================================
    fprintf('Step 2: 计算绝对轨迹 (Trajectory)...\n');
    traj_res = calc_motion_trajectory(full_file_path);
    
    fig2 = figure('Name', '绝对轨迹分析', 'Color', 'white', 'Position', [150, 150, 1000, 800]);
    
    % X Axis
    subplot(3, 1, 1);
    plot(traj_res.frames, traj_res.x.orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
    plot(traj_res.frames, traj_res.x.smooth, 'Color', style.color2, 'LineWidth', style.lw2);
    title(['X Axis Trajectory (Absolute) - ' name_body], 'Interpreter', 'none');
    ylabel('Pos (px)'); legend('Original', 'Stabilized'); grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);
    
    % Y Axis
    subplot(3, 1, 2);
    plot(traj_res.frames, traj_res.y.orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
    plot(traj_res.frames, traj_res.y.smooth, 'Color', style.color2, 'LineWidth', style.lw2);
    title('Y Axis Trajectory (Absolute)'); ylabel('Pos (px)'); grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);
    
    % Rotation
    subplot(3, 1, 3);
    plot(traj_res.frames, traj_res.rotation.orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
    plot(traj_res.frames, traj_res.rotation.smooth, 'Color', style.color2, 'LineWidth', style.lw2);
    title('Rotation Trajectory (Absolute)'); ylabel('Angle (deg)'); grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);
    
    % 保存
    exportgraphics(fig2, fullfile(file_path, [name_body, '_02_trajectory.png']), 'Resolution', 150);
    exportgraphics(fig2, pdf_report_name, 'ContentType', 'vector', 'Append', true); % 追加 PDF

    %% ==================================================
    %% 第三页：频域分析 (Frequency / PSD)
    %% ==================================================
    fprintf('Step 3: 进行频域分析 (PSD)...\n');
    
    % 提取数据 (以X轴为例)
    data_orig = traj_res.x.orig;
    data_smooth = traj_res.x.smooth;
    
    % Welch PSD 计算
    window = hamming(floor(length(data_orig)/2));
    noverlap = floor(length(window)/2);
    nfft = max(256, 2^nextpow2(length(window)));
    
    [pxx_orig, f] = pwelch(data_orig - mean(data_orig), window, noverlap, nfft, fps);
    [pxx_smooth, ~] = pwelch(data_smooth - mean(data_smooth), window, noverlap, nfft, fps);
    
    pdb_orig = 10*log10(pxx_orig);
    pdb_smooth = 10*log10(pxx_smooth);
    
    fig3 = figure('Name', '频域分析', 'Color', 'white', 'Position', [200, 200, 1000, 600]);
    
    plot(f, pdb_orig, 'Color', style.color1, 'LineWidth', 1.5); hold on;
    plot(f, pdb_smooth, 'Color', style.color2, 'LineWidth', 2);
    
    title(['Frequency Domain Analysis (PSD - X Axis) - ' name_body], 'Interpreter', 'none');
    xlabel('Frequency (Hz)');
    ylabel('Power Spectral Density (dB/Hz)');
    legend('Original', 'Stabilized');
    grid on;
    
    % 标注辅助线
    xline(2.0, 'k--', 'Cutoff (2Hz)', 'LabelVerticalAlignment', 'bottom');
    
    % 保存
    exportgraphics(fig3, fullfile(file_path, [name_body, '_03_frequency.png']), 'Resolution', 150);
    exportgraphics(fig3, pdf_report_name, 'ContentType', 'vector', 'Append', true); % 追加 PDF
    
    %% 完成
    fprintf('\n--------------------------------------\n');
    fprintf('分析完成！\n');
    fprintf('PDF 报告已生成: %s\n', pdf_report_name);
    
    % 自动打开 PDF (可选，仅限 Windows)
    if ispc
        winopen(pdf_report_name);
    end

catch ME
    fprintf(2, '[ERROR] 分析过程出错: %s\n', ME.message);
    errordlg(ME.message, '分析出错');
end