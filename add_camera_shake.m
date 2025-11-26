%% MATLAB脚本：模拟手持摄像机抖动效果 (Handheld Camera Shake Simulation)
% 功能：给静止视频添加由于手持拍摄导致的随机抖动（包含平移和旋转）
% 特点：加强了高频抖动分量，包含自动裁剪以去除黑边。

clear; clc; close all;

%% 1. 参数设置 (User Configuration)
videoFile = 'people.mp4';   % 输入视频文件名 (支持 mp4, avi 等)
outputFile = 'shaky_output.avi'; % 输出视频文件名

% --- 抖动幅度设置 ---
max_shift_px = 10;     % 最大平移范围 (像素)
max_angle_deg = 1.5;   % 最大旋转角度 (度)

% --- 抖动频率特性 (核心设置) ---
% weight_jitter 越高，画面"震动"感越强 (高频)
% weight_drift 越高，画面"晃动"感越强 (低频)
weight_jitter = 0.1;   % 高频震颤权重 (0~1) -> 调高这个以满足"高频抖动多"
weight_drift  = 0.5;   % 低频漂移权重 (0~1)

% --- 缩放设置 ---
% 为了防止抖动导致边缘出现黑边，需要稍微放大视频并裁剪中心
zoom_factor = 1.10;    % 1.15 表示放大 15% (需大于抖动幅度以覆盖黑边)

%% 2. 读取视频与初始化
if ~isfile(videoFile)
    error('找不到输入文件: %s，请确认文件名或路径。', videoFile);
end

vr = VideoReader(videoFile);
frameRate = vr.FrameRate;
numFrames = vr.NumFrames;
height = vr.Height;
width = vr.Width;

% 创建视频写入对象
vw = VideoWriter(outputFile, 'Motion JPEG AVI');
vw.FrameRate = frameRate;
open(vw);

fprintf('开始处理视频: %s\n', videoFile);
fprintf('总帧数: %d\n', numFrames);

%% 3. 生成抖动轨迹 (Trajectory Generation)
% 使用随机噪声生成 x, y, theta 的变化量

% 生成高频噪声 (白噪声 - 模拟肌肉震颤)
noise_high_x = -1 + 2 * rand(numFrames, 1); 
noise_high_y = -1 + 2 * rand(numFrames, 1);
noise_high_r = -1 + 2 * rand(numFrames, 1);

% 生成低频噪声 (平滑滤波后的噪声 - 模拟手臂漂移)
% 使用 movmean (移动平均) 来平滑
smooth_window = round(frameRate * 0.5); % 0.5秒的平滑窗口
noise_low_x = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);
noise_low_y = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);
noise_low_r = smoothdata(randn(numFrames, 1), 'gaussian', smooth_window);

% 归一化低频噪声到 -1 到 1 之间
normalize = @(v) (v - min(v)) / (max(v) - min(v)) * 2 - 1;
noise_low_x = normalize(noise_low_x);
noise_low_y = normalize(noise_low_y);
noise_low_r = normalize(noise_low_r);

% 混合高频和低频，并应用幅度参数
dx = (noise_high_x * weight_jitter + noise_low_x * weight_drift);
dy = (noise_high_y * weight_jitter + noise_low_y * weight_drift);
d_theta = (noise_high_r * weight_jitter + noise_low_r * weight_drift);

% 重新归一化并映射到最大幅度
dx = normalize(dx) * max_shift_px;
dy = normalize(dy) * max_shift_px;
d_theta = normalize(d_theta) * max_angle_deg;

% 保存轨迹数据以便后续分析
trajectory_data = table((1:numFrames)', dx, dy, d_theta, ...
    'VariableNames', {'Frame', 'ShiftX', 'ShiftY', 'RotationDeg'});

%% 4. 逐帧处理视频 (Frame Processing Loop)
hWaitBar = waitbar(0, '正在生成抖动视频...');

% 计算裁剪窗口 (基于 zoom_factor)
new_h = floor(height / zoom_factor);
new_w = floor(width / zoom_factor);
% 裁剪起始中心点 (未抖动前)
center_y = floor((height - new_h) / 2);
center_x = floor((width - new_w) / 2);

for k = 1:numFrames
    if hasFrame(vr)
        frame = readFrame(vr);
    else
        break; 
    end
    
    % --- 核心变换逻辑 ---
    
    % 1. 缩放 (先放大)
    frame_zoomed = imresize(frame, zoom_factor);
    
    % 2. 构建仿射变换矩阵 (旋转 + 平移)
    % 注意：dx(k) 和 dy(k) 这里反向应用，模拟摄像机移动导致画面反向移动
    theta = d_theta(k);
    tx = dx(k); 
    ty = dy(k);
    
    % 旋转矩阵
    R = [cosd(theta)  sind(theta)  0;
        -sind(theta) cosd(theta)  0;
         0            0            1];
    % 平移矩阵
    T = [1  0  0;
         0  1  0;
         tx ty 1];
     
    % 组合变换
    tform = affine2d(R * T);
    
    % 3. 应用变换
    % OutputView 设置为 'same' 保持大小，但我们会再次裁剪
    frame_shaken = imwarp(frame_zoomed, tform, 'OutputView', imref2d(size(frame_zoomed)));
    
    % 4. 中心裁剪 (去除变换可能带来的边缘黑边)
    % 计算当前放大的图像中心
    [zh, zw, ~] = size(frame_shaken);
    crop_rect = [floor((zw-width)/2), floor((zh-height)/2), width-1, height-1];
    
    frame_final = imcrop(frame_shaken, crop_rect);
    
    % 确保尺寸严格匹配 (防止舍入误差)
    frame_final = imresize(frame_final, [height, width]);
    
    writeVideo(vw, frame_final);
    
    if mod(k, 20) == 0
        waitbar(k/numFrames, hWaitBar, sprintf('处理进度: %d/%d 帧', k, numFrames));
    end
end

close(vw);
close(hWaitBar);
fprintf('视频处理完成！输出文件: %s\n', outputFile);

%% 5. 输出抖动轨迹图 (Plot Trajectories)
figure('Name', '抖动轨迹分析', 'Color', 'white', 'Position', [100, 100, 800, 600]);

subplot(3,1,1);
plot(trajectory_data.Frame, trajectory_data.ShiftX, 'b', 'LineWidth', 1);
title('X 轴水平抖动 (像素)');
ylabel('位移 (px)'); grid on;

subplot(3,1,2);
plot(trajectory_data.Frame, trajectory_data.ShiftY, 'r', 'LineWidth', 1);
title('Y 轴垂直抖动 (像素)');
ylabel('位移 (px)'); grid on;

subplot(3,1,3);
plot(trajectory_data.Frame, trajectory_data.RotationDeg, 'g', 'LineWidth', 1);
title('旋转抖动 (角度)');
ylabel('角度 (deg)'); xlabel('帧数 (Frame)'); grid on;

% 可以在此保存轨迹数据
% save('shake_trajectory.mat', 'trajectory_data');