%% 视频防抖效果批量评价脚本 (支持不同格式匹配)
% 功能：自动遍历文件夹，计算 ITF 和 SSIM，并输出结果表格
clear; clc;

%% --- 1. 参数配置区 ---

% 防抖视频配置 (avi格式)
stab_folder_root = 'D:\Matlab Code\video_stable\my_algo\my_data\ts';  % 防抖视频文件夹路径
stab_file_ext = '*.mp4';                                                        % 防抖视频的后缀格式
suffix_pattern = '_stabilized';                                           % 防抖文件名的特征后缀 (用于识别)

% 参考视频配置 (mp4格式)
% 如果不需要计算 SSIM，请将此变量设为 ''
ref_folder_root = ''; % 原视频文件夹路径
ref_file_ext = '.mp4';                                          % 原视频的后缀 (注意这里不要加 *)

%% --- 2. 初始化 ---

% 检查是否需要计算 SSIM
calc_ssim_flag = false;
if ~isempty(ref_folder_root) && exist(ref_folder_root, 'dir')
    calc_ssim_flag = true;
    fprintf('模式: 计算 ITF (稳定度) 和 SSIM (失真度)\n');
    fprintf('防抖视频格式: %s | 参考视频格式: %s\n', stab_file_ext, ref_file_ext);
else
    fprintf('模式: 仅计算 ITF (稳定度)\n');
end

% 获取所有防抖视频文件 (递归搜索)
search_pattern = fullfile(stab_folder_root, '**', stab_file_ext);
file_list = dir(search_pattern);

% 过滤掉文件夹
file_list = file_list(~[file_list.isdir]);

% 二次确认文件名包含指定特征后缀 (防止误读其他 avi 文件)
keep_idx = false(length(file_list), 1);
for i = 1:length(file_list)
    if contains(file_list(i).name, suffix_pattern)
        keep_idx(i) = true;
    end
end
file_list = file_list(keep_idx);

if isempty(file_list)
    error('未在指定路径找到包含 "%s" 且格式为 %s 的视频文件。', suffix_pattern, stab_file_ext);
end

fprintf('共找到 %d 个防抖视频文件，开始处理...\n', length(file_list));
fprintf('------------------------------------------------------------\n');

%% --- 3. 循环处理 ---

% 存储结果
results = struct('FileName', {}, 'ITF', {}, 'SSIM', {});

for i = 1:length(file_list)
    % 获取当前防抖视频完整路径
    stab_video_path = fullfile(file_list(i).folder, file_list(i).name);
    file_name = file_list(i).name; % 例如: video1_stabilized.avi
    
    fprintf('[%d/%d] 正在处理: %s ... ', i, length(file_list), file_name);
    
    % --- 计算 ITF ---
    itf_val = calculate_itf(stab_video_path);
    
    % --- 计算 SSIM (如果开启) ---
    ssim_val = NaN;
    if calc_ssim_flag
        % 核心匹配逻辑修改：
        % 1. 分离文件名和扩展名 -> ('video1_stabilized', '.avi')
        [~, name_no_ext, ~] = fileparts(file_name); 
        
        % 2. 去除防抖特征后缀 -> 'video1'
        base_name = strrep(name_no_ext, suffix_pattern, '');
        
        % 3. 拼接参考视频的后缀 -> 'video1.mp4'
        target_ref_name = [base_name, ref_file_ext];
        
        % 在参考文件夹中递归寻找该原始文件
        orig_search_pattern = fullfile(ref_folder_root, '**', target_ref_name);
        orig_files = dir(orig_search_pattern);
        
        if isempty(orig_files)
            warning('未找到对应的参考视频: %s', target_ref_name);
        else
            % 取找到的第一个文件
            ref_video_path = fullfile(orig_files(1).folder, orig_files(1).name);
            
            % 调用之前提供的带自动对齐功能的 SSIM 计算函数
            ssim_val = calculate_video_ssim(stab_video_path, ref_video_path);
        end
    end
    
    % 打印单行结果
    if calc_ssim_flag
        fprintf('ITF: %.2f dB | SSIM: %.4f\n', itf_val, ssim_val);
    else
        fprintf('ITF: %.2f dB\n', itf_val);
    end
    
    % 保存结果到结构体
    results(i).FileName = file_name;
    results(i).ITF = itf_val;
    results(i).SSIM = ssim_val;
end

%% --- 4. 结果汇总与保存 ---

fprintf('------------------------------------------------------------\n');
fprintf('处理完成。\n');

% 将结果转换为 Table 方便查看
T = struct2table(results);
disp(T);

% 保存为 CSV
output_csv_name = strcat(stab_folder_root,'\stabilization_evaluation_results.csv') ;
try
    writetable(T, output_csv_name);
    fprintf('结果已保存至 %s\n', output_csv_name);
catch
    warning('无法写入 CSV 文件，可能是文件被占用。');
end