clear; clc; close all;

% 定义文件名
project_path = 'D:\Matlab Code\video_stable\';
file_path = 'stable_data\01_ir_shaky_stabilized_trajectory.txt';
target_file = strcat(project_path,file_path);

% 定义色彩和粗细
color1 = '#F36E43';
color2 = '#4A64AE';
line_width1 = 1;
line_width2 = 2;

%% 1. 计算相对位移
results = calc_trajectory_stats(target_file);

fprintf('--- 相对位移结果: %s ---\n', results.file_info.filename);
fprintf('--------------------------------------\n');
fprintf('X 轴抖动抑制率: %.2f%%\n', results.x.reduction);
fprintf('Y 轴抖动抑制率: %.2f%%\n', results.y.reduction);
fprintf('旋转抖动抑制率: %.2f%%\n', results.rotation.reduction);

% 1.1. 可视化分析
figure('Name', '相对位移(帧间抖动)分析', 'Color', 'white', 'Position', [100, 100, 1000, 800]);

% --- 子图 1: X轴相对位移 ---
subplot(3, 1, 1);
plot(results.time_series, results.x.delta_orig, 'Color', color1, 'LineWidth', line_width1); hold on; % 半透明红色
plot(results.time_series, results.x.delta_smooth, 'Color', color2, 'LineWidth', line_width2);
title('X 轴相对位移 (帧间变化量)');
xlabel('帧数 (Frame)'); ylabel('位移差 (px)');
legend('Original', 'Smoothed', 'Location', 'northwest');
grid on; xlim([min(results.time_series) max(results.time_series)]);

% --- 子图 2: Y轴相对位移 ---
subplot(3, 1, 2);
plot(results.time_series, results.y.delta_orig, 'Color', color1, 'LineWidth', line_width1); hold on;
plot(results.time_series, results.y.delta_smooth, 'Color', color2, 'LineWidth', line_width2);
title('Y 轴相对位移 (帧间变化量)');
xlabel('帧数 (Frame)'); ylabel('位移差 (px)');
legend('Original', 'Smoothed', 'Location', 'northwest');
grid on; xlim([min(results.time_series) max(results.time_series)]);

% --- 子图 3: 旋转相对位移 ---
subplot(3, 1, 3);
plot(results.time_series, results.rotation.delta_orig, 'Color', color1, 'LineWidth', line_width1); hold on;
plot(results.time_series, results.rotation.delta_smooth, 'Color', color2, 'LineWidth', line_width2); % 黑色为平滑后
title('旋转相对位移 (帧间角度变化)');
xlabel('帧数 (Frame)'); ylabel('角度差 (deg/rad)');
legend('Original', 'Smoothed', 'Location', 'northwest');
grid on; xlim([min(results.time_series) max(results.time_series)]);

% 导出图像
exportgraphics(gcf, 'trajectory_stats.png', 'Resolution', 300); 
exportgraphics(gcf, 'trajectory_stats.pdf', 'ContentType', 'vector');

%% 2. 计算轨迹
traj_res = calc_motion_trajectory(target_file);

fprintf('--- 轨迹分析结果: %s ---\n', traj_res.file_info.filename);
fprintf('--------------------------------------\n');
fprintf('X轴: 最大偏差 = %.4f px, RMSE = %.4f\n', traj_res.x.max_dev, traj_res.x.rmse);
fprintf('Y轴: 最大偏差 = %.4f px, RMSE = %.4f\n', traj_res.y.max_dev, traj_res.y.rmse);
fprintf('旋转: 最大偏差 = %.4f,    RMSE = %.4f\n', traj_res.rotation.max_dev, traj_res.rotation.rmse);

% 1.1. 可视化分析
figure('Name', '累计位移分析', 'Color', 'white', 'Position', [100, 100, 1000, 800]);

% --- 子图 1: X轴相对位移 ---
subplot(3, 1, 1);
plot(traj_res.frames, traj_res.x.orig, 'Color', color1, 'LineWidth', line_width1); hold on; % 半透明红色
plot(traj_res.frames, traj_res.x.smooth, 'Color', color2, 'LineWidth', line_width2);
title('X 轴运动轨迹 (累积位移)');
xlabel('帧数 (Frame)'); ylabel('位移 (px)');
legend('Original', 'Smoothed', 'Location', 'northwest');
grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);

% --- 子图 2: Y轴相对位移 ---
subplot(3, 1, 2);
plot(traj_res.frames, traj_res.y.orig, 'Color', color1, 'LineWidth', line_width1); hold on;
plot(traj_res.frames, traj_res.y.smooth, 'Color', color2, 'LineWidth', line_width2);
title('Y 轴运动轨迹 (累积位移)');
xlabel('帧数 (Frame)'); ylabel('位移 (px)');
legend('Original', 'Smoothed', 'Location', 'northwest');
grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);

% --- 子图 3: 旋转相对位移 ---
subplot(3, 1, 3);
plot(traj_res.frames, traj_res.rotation.orig, 'Color', color1, 'LineWidth', line_width1); hold on;
plot(traj_res.frames, traj_res.rotation.smooth, 'Color', color2, 'LineWidth', line_width2); % 黑色为平滑后
title('旋转运动轨迹 (累积角度变化)');
xlabel('帧数 (Frame)'); ylabel('角度 (deg/rad)');
legend('Original', 'Smoothed', 'Location', 'northwest');
grid on; xlim([min(traj_res.frames) max(traj_res.frames)]);

% 导出图像
exportgraphics(gcf, 'motion_trajectory.png', 'Resolution', 300); 
exportgraphics(gcf, 'motion_trajectory.pdf', 'ContentType', 'vector');


%% 频域分析
cutoff = 2.0;
fprintf('正在进行频域分析...\n');
[dB_gain, ratio] = analyze_stabilization_freq(traj_res.x.orig, traj_res.x.smooth, 25, cutoff);
fprintf('----------------------------------\n');
fprintf('高频能量抑制比: %.2f dB\n', dB_gain);
fprintf('能量降低倍数:   %.2f 倍\n', ratio);
fprintf('----------------------------------\n');