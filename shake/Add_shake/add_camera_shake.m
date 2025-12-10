%% MATLAB 批量生成抖动视频测试脚本
clear; clc;

%% 1. 配置路径和参数
% 输入文件夹路径
project_path = 'D:\Matlab Code\video_stable\';
input_path = 'shake\cap_data\ir\No_SSIM'; 
output_path = 'shake\output\ir\No_SSIM';

input_folder = fullfile(project_path, input_path);
output_folder = fullfile(project_path, output_path);

% -----------------------------------------------------------
% [核心修改] 选择抖动类型: 'handheld' | 'drone' | 'random'
% -----------------------------------------------------------
shake_type = 'handheld'; 

shake_params = struct();
shake_params.zoom_factor = 1.2; % 通用缩放

switch shake_type
    case 'handheld'
        % 手持: 大幅度，慢漂移，低频为主
        shake_params.max_shift_px  = 20;   % 较大的位移
        shake_params.max_angle_deg = 1.0;  % 明显的旋转
        shake_params.weight_jitter = 0.05; % 极少的高频抖动
        shake_params.weight_drift  = 0.95; % 主要由低频漂移主导
        shake_params.smooth_sec    = 0.5;  % 
        
    case 'drone'
        % 无人机: 小幅度，高频震动 (电机嗡嗡声)，几乎无旋转
        shake_params.max_shift_px  = 8;    % 位移较小
        shake_params.max_angle_deg = 0.5;  % 几乎不旋转 (云台会修正旋转)
        shake_params.weight_jitter = 0.6;  % 主要由高频震颤主导
        shake_params.weight_drift  = 0.4;  % 少量的风阻漂移
        shake_params.smooth_sec    = 0.5;  % 漂移变化也很快
        
    case 'random'
        % 无规则: 混乱，中等幅度，频率混合
        shake_params.max_shift_px  = 15;
        shake_params.max_angle_deg = 1.5;
        shake_params.weight_jitter = 0.5;  % 高频低频各一半
        shake_params.weight_drift  = 0.5;
        shake_params.smooth_sec    = 0.5;  % 中等的平滑度        
    otherwise
        error('未知的抖动类型: %s', shake_type);
end

fprintf('当前模式: %s \n', shake_type);
disp(shake_params);

%% 2. 准备文件列表
if ~isfolder(output_folder)
    mkdir(output_folder);
end

file_extensions = {'*.mp4', '*.avi', '*.mov'};
file_list = [];
for i = 1:length(file_extensions)
    file_list = [file_list; dir(fullfile(input_folder, file_extensions{i}))];
end

if isempty(file_list)
    error('在 %s 中没有找到视频文件。', input_folder);
end

%% 3. 循环批量处理
total_files = length(file_list);

for i = 1:total_files
    file_name = file_list(i).name;
    full_input_path = fullfile(file_list(i).folder, file_name);
    
    [~, name_body, ~] = fileparts(file_name);
    
    % 输出文件名带上后缀，方便区分
    output_video_name = sprintf('%s%s.avi', name_body);
    full_output_video_path = fullfile(output_folder, output_video_name);
    
    fprintf('\n[%d/%d] 正在处理: %s (%s)...\n', i, total_files, file_name, shake_type);
    
    try
        % --- A. 调用核心函数 ---
        traj = sim_shake(full_input_path, full_output_video_path, shake_params);
        
        % --- B. 数据转换与保存 (TXT) ---
        orig_x = traj.ShiftX;
        orig_y = traj.ShiftY;
        orig_r = traj.RotationDeg;
        
        % 差分计算
        curr_x = [orig_x(1); diff(orig_x)];
        curr_y = [orig_y(1); diff(orig_y)];
        curr_r = [orig_r(1); diff(orig_r)];
        
        frames = traj.Frame - 1;
        
        export_table = table(frames, curr_x, curr_y, curr_r, orig_x, orig_y, orig_r, ...
            'VariableNames', {'帧', '当前X', '当前Y', '当前旋转', '原始X', '原始Y', '原始旋转'});
        
        % TXT 文件名也加上后缀
        txt_name = fullfile(output_folder, sprintf('%s%s_trajectory.txt', name_body));
        writetable(export_table, txt_name, 'Delimiter', ' ');
        
        fprintf('  -> 视频: %s\n', output_video_name);
        
    catch ME
        fprintf(2, '处理出错: %s\n', ME.message);
    end
end

fprintf('\n所有任务完成！\n');