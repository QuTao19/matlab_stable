function stat_results = calc_trajectory_stats(filename)
% CALC_TRAJECTORY_STATS 计算轨迹的相对位移（帧间抖动）及统计指标
%
% 输入:
%   filename - 轨迹数据文件的路径 (字符串)
%
% 输出:
%   stat_results - 包含分析结果的结构体，结构如下：
%       .file_info     : 文件名及总帧数
%       .time_series   : 对齐后的时间序列（帧号），用于绘图
%       .x             : X轴相关数据 (delta_orig, delta_smooth, std_orig, std_smooth, reduction)
%       .y             : Y轴相关数据 (同上)
%       .rotation      : 旋转角相关数据 (同上)
%
% 示例:
%   res = calc_trajectory_stats('spark_stabilized_trajectory.txt');
%   fprintf('X轴优化比例: %.2f%%\n', res.x.reduction);

    %% 1. 输入检查
    if nargin < 1 || isempty(filename)
        error('请提供文件名作为输入参数。');
    end
    
    if ~isfile(filename)
        error('找不到文件: %s，请确认路径正确。', filename);
    end

    %% 2. 读取数据
    % 自动识别导入选项，保留原始表头
    opts = detectImportOptions(filename);
    opts.VariableNamingRule = 'preserve'; 
    try
        data = readtable(filename, opts);
    catch ME
        error('读取文件失败: %s', ME.message);
    end
    
    total_frames = height(data);

    %% 3. 提取数据
    % 根据原始脚本的列索引提取 (假设列顺序固定)
    frames_all = data{:, 1}; 
    
    % 原始轨迹 (Cumulative)
    orig_x = data{:, 5};
    orig_y = data{:, 6};
    orig_r = data{:, 7};
    
    % 平滑轨迹 (Cumulative)
    smooth_x = data{:, 8};
    smooth_y = data{:, 9};
    smooth_r = data{:, 10};

    %% 4. 核心计算：计算帧间差分 (Delta / Relative Displacement)
    % diff 计算后长度会比原数组少 1
    delta_orig_x = diff(orig_x);
    delta_orig_y = diff(orig_y);
    delta_orig_r = diff(orig_r);
    
    delta_smooth_x = diff(smooth_x);
    delta_smooth_y = diff(smooth_y);
    delta_smooth_r = diff(smooth_r);

    % 对齐用于分析的帧号 (从第2帧开始)
    analysis_frames = frames_all(2:end);

    %% 5. 统计分析与结构体封装
    
    % --- 初始化输出结构体 ---
    stat_results = struct();
    
    % 基础信息
    stat_results.file_info.filename = filename;
    stat_results.file_info.total_frames = total_frames;
    stat_results.time_series = analysis_frames; % 方便外部绘图使用

    % --- 封装辅助函数：计算单维度的统计数据 ---
    % 这样代码更整洁，避免重复
    stat_results.x = analyze_dimension(delta_orig_x, delta_smooth_x);
    stat_results.y = analyze_dimension(delta_orig_y, delta_smooth_y);
    stat_results.rotation = analyze_dimension(delta_orig_r, delta_smooth_r);

end

function dim_stats = analyze_dimension(d_orig, d_smooth)
% 内部辅助函数：计算标准差和减少比例
    std_orig = std(d_orig);
    std_smooth = std(d_smooth);
    
    % 防止分母为0
    if std_orig == 0
        reduction = 0;
    else
        reduction = (1 - std_smooth / std_orig) * 100;
    end
    
    dim_stats.delta_orig = d_orig;       % 原始帧间位移序列
    dim_stats.delta_smooth = d_smooth;   % 平滑后帧间位移序列
    dim_stats.std_orig = std_orig;       % 原始抖动标准差
    dim_stats.std_smooth = std_smooth;   % 平滑后抖动标准差
    dim_stats.reduction = reduction;     % 优化比例 (%)
end