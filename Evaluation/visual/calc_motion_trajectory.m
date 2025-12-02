function traj_results = calc_motion_trajectory(filename)
% CALC_MOTION_TRAJECTORY 读取并计算防抖前后的绝对运动轨迹及统计量
%
% 输入:
%   filename - 轨迹数据文件的路径 (字符串)
%
% 输出:
%   traj_results - 包含分析结果的结构体，结构如下：
%       .file_info     : 文件名及总帧数
%       .frames        : 帧号序列
%       .x             : X轴相关数据 (orig, smooth, jitter, max_dev, rmse)
%       .y             : Y轴相关数据 (同上)
%       .rotation      : 旋转角相关数据 (同上)
%
% 示例:
%   res = calc_motion_trajectory('spark_stabilized_trajectory.txt');
%   fprintf('X轴平均抖动(RMSE): %.4f\n', res.x.rmse);

    %% 1. 输入检查
    if nargin < 1 || isempty(filename)
        error('请提供文件名作为输入参数。');
    end
    
    if ~isfile(filename)
        error('找不到文件: %s，请确认路径正确。', filename);
    end

    %% 2. 读取数据
    opts = detectImportOptions(filename);
    opts.VariableNamingRule = 'preserve'; 
    try
        data = readtable(filename, opts);
    catch ME
        error('读取文件失败: %s', ME.message);
    end
    
    %% 3. 提取数据列
    % 假设列结构固定: 
    % Col 1: Frame
    % Col 5-7: Orig X, Y, R
    % Col 8-10: Smooth X, Y, R
    
    frames = data{:, 1}; 
    
    % 原始轨迹 (Original Trajectory)
    orig_x = data{:, 5};
    orig_y = data{:, 6};
    orig_r = data{:, 7};
    
    % 平滑轨迹 (Smoothed Trajectory)
    smooth_x = data{:, 8};
    smooth_y = data{:, 9};
    smooth_r = data{:, 10};

    %% 4. 数据封装与统计计算
    
    % 初始化输出
    traj_results = struct();
    traj_results.file_info.filename = filename;
    traj_results.file_info.total_frames = length(frames);
    traj_results.frames = frames;

    % 使用内部函数统一处理各维度
    traj_results.x = analyze_axis_trajectory(orig_x, smooth_x);
    traj_results.y = analyze_axis_trajectory(orig_y, smooth_y);
    traj_results.rotation = analyze_axis_trajectory(orig_r, smooth_r);

end

function axis_stats = analyze_axis_trajectory(orig_data, smooth_data)
% 内部辅助函数：计算轨迹偏差统计量
    
    % 计算抖动分量 (Jitter Component) / 矫正量
    % 即：算法为了平滑去除了多少偏移
    jitter_diff = orig_data - smooth_data;
    abs_jitter = abs(jitter_diff);
    
    % 统计指标
    max_deviation = max(abs_jitter); % 最大抖动偏差
    rmse_val = rms(jitter_diff);     % 均方根误差 (整体抖动能量)
    
    % 封装结果
    axis_stats.orig = orig_data;         % 原始轨迹数据
    axis_stats.smooth = smooth_data;     % 平滑后轨迹数据
    axis_stats.jitter_component = jitter_diff; % 每一帧的偏差值
    axis_stats.max_dev = max_deviation;  % 统计值：最大偏差
    axis_stats.rmse = rmse_val;          % 统计值：RMSE
end