%% MATLAB 批量生成抖动视频测试脚本
clear; clc;

%% 1. 配置路径和参数
% 输入文件夹路径 (可以是相对路径或绝对路径)
project_path = 'D:\Matlab Code\video_stable\';
input_path = 'cap_data\'; 
% 输出文件夹路径 (如果不存会自动创建)
output_path = 'output_shaky\';
input_folder = strcat(project_path,input_path);
output_folder = strcat(project_path,output_path);

% 定义抖动参数
shake_params = struct();
shake_params.max_shift_px = 15;     % 最大平移像素
shake_params.max_angle_deg = 1.5;   % 最大旋转角度
shake_params.weight_jitter = 0.1;  % 高频震颤权重
shake_params.weight_drift  = 0.9;   % 低频漂移权重
shake_params.zoom_factor   = 1.15;   % 缩放比例

%% 2. 准备文件列表
if ~isfolder(output_folder)
    mkdir(output_folder);
end

% 支持的文件格式
file_extensions = {'*.mp4', '*.avi', '*.mov'};
file_list = [];
for i = 1:length(file_extensions)
    file_list = [file_list; dir(fullfile(input_folder, file_extensions{i}))];
end

if isempty(file_list)
    error('在 %s 中没有找到视频文件。', input_folder);
end

fprintf('共发现 %d 个视频文件，准备开始处理...\n', length(file_list));

%% 3. 循环批量处理
total_files = length(file_list);

for i = 1:total_files
    file_name = file_list(i).name;
    full_input_path = fullfile(file_list(i).folder, file_name);
    
    % 获取文件名主体 (不含扩展名)
    [~, name_body, ~] = fileparts(file_name);
    
    % 定义输出文件名
    output_video_name = sprintf('%s_shaky.avi', name_body);
    full_output_video_path = fullfile(output_folder, output_video_name);
    
    fprintf('\n[%d/%d] 正在处理: %s ...\n', i, total_files, file_name);
    
    try
        % --- A. 调用核心函数生成视频 ---
        % traj 包含: Frame, ShiftX, ShiftY, RotationDeg (这些是绝对/累计位移)
        traj = sim_shake(full_input_path, full_output_video_path, shake_params);
        
        % --- B. 数据转换与保存 (TXT) ---
        % 1. 提取原始轨迹 (绝对累计位移)
        orig_x = traj.ShiftX;
        orig_y = traj.ShiftY;
        orig_r = traj.RotationDeg;
        
        % 2. 计算当前轨迹 (帧间差分/Delta)
        % 第一帧的差分通常等于其绝对值(假设从0开始)，或者设为0。这里采用 data(1)-0 的逻辑
        curr_x = [orig_x(1); diff(orig_x)];
        curr_y = [orig_y(1); diff(orig_y)];
        curr_r = [orig_r(1); diff(orig_r)];
        
        % 3. 构建符合要求的 Table
        % 列顺序: 帧, 当前X, 当前Y, 当前旋转, 原始X, 原始Y, 原始旋转
        frames = traj.Frame - 1; % 你的示例中帧是从 0 开始的，这里做个调整（可选）
        
        export_table = table(frames, curr_x, curr_y, curr_r, orig_x, orig_y, orig_r, ...
            'VariableNames', {'帧', '当前X', '当前Y', '当前旋转', '原始X', '原始Y', '原始旋转'});
        
        % 4. 保存为 TXT 文件
        txt_name = fullfile(output_folder, sprintf('%s_trajectory.txt', name_body));
        
        % 使用 writetable 保存，指定空格分隔
        writetable(export_table, txt_name, 'Delimiter', ' ');
        
        fprintf('  -> 视频已保存: %s\n', output_video_name);
        fprintf('  -> 轨迹已保存: %s_trajectory.txt\n', name_body);
        
    catch ME
        fprintf(2, '处理文件 %s 时出错: %s\n', file_name, ME.message);
    end
end

fprintf('\n所有任务完成！结果已保存在: %s\n', output_folder);