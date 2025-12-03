%% MATLAB 递归批处理脚本：防抖数据全维度分析 (支持子文件夹)
% 功能：递归遍历文件夹及子文件夹下的轨迹数据，生成PNG图片，并合并为PDF报告
clear; clc; close all;

%% 1. 全局配置
% --- 路径设置 ---
% 请修改为你的数据根目录路径
data_folder = 'D:\Matlab Code\video_stable\my_algo\my_data\'; 

% --- 参数设置 ---
fps = 50;                 % 视频采样率
style.color1 = '#F36E43'; % 原始数据颜色
style.color2 = '#4A64AE'; % 处理后颜色
style.lw1 = 1;            
style.lw2 = 2;            

% 检查文件夹
if ~isfolder(data_folder)
    error('找不到文件夹: %s', data_folder);
end

% --- 递归搜索文件 ---
% 使用 '**' 通配符搜索所有子文件夹
file_list = dir(fullfile(data_folder, '**', '*.txt'));
% 过滤掉可能存在的文件夹项，只保留文件
file_list = file_list(~[file_list.isdir]);

if isempty(file_list)
    error('在 %s 及其子文件夹中没有找到 .txt 文件。', data_folder);
end

fprintf('共发现 %d 个文件 (包含子文件夹)，开始生成综合报告...\n', length(file_list));

%% 2. 循环处理
for i = 1:length(file_list)
    % --- 获取当前文件的路径信息 ---
    current_file_name = file_list(i).name;
    current_folder = file_list(i).folder; % 获取当前文件所在的具体子文件夹
    full_file_path = fullfile(current_folder, current_file_name);
    
    [~, name_body, ~] = fileparts(current_file_name);
    
    % 计算相对于根目录的路径用于显示进度 (例如 "\Scene1\data.txt")
    rel_path = erase(current_folder, data_folder);
    
    % 定义输出路径：直接保存在当前子文件夹内
    pdf_report_name = fullfile(current_folder, [name_body, '_report.pdf']);
    
    fprintf('\n[%d/%d] 正在处理: ...%s\\%s\n', i, length(file_list), rel_path, current_file_name);
    
    try
        %% ==================================================
        %% 第一页：相对位移分析 (Relative/Jitter)
        %% ==================================================
        results = calc_trajectory_stats(full_file_path);
        
        fig1 = figure('Name', '相对位移', 'Color', 'white', 'Position', [0, 0, 1000, 800], 'Visible', 'off');
        
        subplot(3, 1, 1);
        plot(results.time_series, results.x.delta_orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
        plot(results.time_series, results.x.delta_smooth, 'Color', style.color2, 'LineWidth', style.lw2);
        title(['X Axis Jitter (Relative) - ' name_body], 'Interpreter', 'none');
        ylabel('Delta (px)'); legend('Original', 'Stabilized'); grid on; xlim([min(results.time_series) max(results.time_series)]);
        
        subplot(3, 1, 2);
        plot(results.time_series, results.y.delta_orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
        plot(results.time_series, results.y.delta_smooth, 'Color', style.color2, 'LineWidth', style.lw2);
        title('Y Axis Jitter (Relative)'); ylabel('Delta (px)'); grid on; xlim([min(results.time_series) max(results.time_series)]);
        
        subplot(3, 1, 3);
        plot(results.time_series, results.rotation.delta_orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
        plot(results.time_series, results.rotation.delta_smooth, 'Color', style.color2, 'LineWidth', style.lw2);
        title('Rotation Jitter (Relative)'); ylabel('Delta (deg)'); grid on; xlim([min(results.time_series) max(results.time_series)]);
        
        % 保存 PNG 到子文件夹
        exportgraphics(fig1, fullfile(current_folder, [name_body, '_01_jitter.png']), 'Resolution', 150);
        % 保存 PDF (第一页)
        exportgraphics(fig1, pdf_report_name, 'ContentType', 'vector'); 
        
        close(fig1);

        %% ==================================================
        %% 第二页：绝对轨迹分析 (Absolute Trajectory)
        %% ==================================================
        traj_res = calc_motion_trajectory(full_file_path);
        
        fig2 = figure('Name', '绝对轨迹', 'Color', 'white', 'Position', [0, 0, 1000, 800], 'Visible', 'off');
        
        subplot(3, 1, 1);
        plot(traj_res.frames, traj_res.x.orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
        plot(traj_res.frames, traj_res.x.smooth, 'Color', style.color2, 'LineWidth', style.lw2);
        title(['X Axis Trajectory (Absolute) - ' name_body], 'Interpreter', 'none');
        ylabel('Position (px)'); legend('Original', 'Stabilized'); grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);
        
        subplot(3, 1, 2);
        plot(traj_res.frames, traj_res.y.orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
        plot(traj_res.frames, traj_res.y.smooth, 'Color', style.color2, 'LineWidth', style.lw2);
        title('Y Axis Trajectory (Absolute)'); ylabel('Position (px)'); grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);
        
        subplot(3, 1, 3);
        plot(traj_res.frames, traj_res.rotation.orig, 'Color', style.color1, 'LineWidth', style.lw1); hold on;
        plot(traj_res.frames, traj_res.rotation.smooth, 'Color', style.color2, 'LineWidth', style.lw2);
        title('Rotation Trajectory (Absolute)'); ylabel('Angle (deg)'); grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);

        % 保存 PNG 到子文件夹
        exportgraphics(fig2, fullfile(current_folder, [name_body, '_02_trajectory.png']), 'Resolution', 150);
        % 追加 PDF (第二页)
        exportgraphics(fig2, pdf_report_name, 'ContentType', 'vector', 'Append', true);
        
        close(fig2);

        %% ==================================================
        %% 第三页：频域分析 (Frequency Domain / PSD)
        %% ==================================================
        
        data_orig = traj_res.x.orig;
        data_smooth = traj_res.x.smooth;
        
        % 计算 PSD (使用 Welch 方法)
        window = hamming(floor(length(data_orig)/2));
        noverlap = floor(length(window)/2);
        nfft = max(256, 2^nextpow2(length(window)));
        
        % 加上 try-catch 防止数据过短导致 pwelch 报错
        try
            [pxx_orig, f] = pwelch(data_orig - mean(data_orig), window, noverlap, nfft, fps);
            [pxx_smooth, ~] = pwelch(data_smooth - mean(data_smooth), window, noverlap, nfft, fps);
            
            % 转换为 dB
            pdb_orig = 10*log10(pxx_orig);
            pdb_smooth = 10*log10(pxx_smooth);
            
            fig3 = figure('Name', '频域分析', 'Color', 'white', 'Position', [0, 0, 1000, 600], 'Visible', 'off');
            
            plot(f, pdb_orig, 'Color', style.color1, 'LineWidth', 1.5); hold on;
            plot(f, pdb_smooth, 'Color', style.color2, 'LineWidth', 2);
            
            title(['Frequency Domain Analysis (PSD - X Axis) - ' name_body], 'Interpreter', 'none');
            xlabel('Frequency (Hz)');
            ylabel('Power Spectral Density (dB/Hz)');
            legend('Original Jitter', 'Residual Jitter');
            grid on;
            
            xline(2.0, 'k--', 'Cutoff (2Hz)'); 
            text(0.5, max(pdb_orig), 'Voluntary Motion', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
            text(3.0, max(pdb_orig), 'High Freq Jitter', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
            
            % 保存 PNG 到子文件夹
            exportgraphics(fig3, fullfile(current_folder, [name_body, '_03_frequency.png']), 'Resolution', 150);
            % 追加 PDF (第三页)
            exportgraphics(fig3, pdf_report_name, 'ContentType', 'vector', 'Append', true);
            
            close(fig3);
        catch freq_err
             fprintf('    [警告] 频域分析失败 (可能数据太短): %s\n', freq_err.message);
        end
        
        fprintf('  -> 报告已生成: %s\n', pdf_report_name);

    catch ME
        fprintf(2, '  [ERROR] %s 处理失败: %s\n', current_file_name, ME.message);
        close all; 
    end
end

fprintf('\n所有处理完成。\n');