%% 批量视频质量评估脚本 (优化版：先找文件，再计算)
% 功能：遍历结果文件夹，优先寻找参考视频，若存在则计算 ITF, PSNR, SSIM 并汇总
clear; clc;

%% 1. 配置路径
% 存放防抖后视频的文件夹 (待测视频)
stable_folder = 'D:\Matlab Code\video_stable\stable_data\add_shake'; 
% 存放原始参考视频的文件夹 (GT视频)
ref_folder = 'D:\Matlab Code\video_stable\unstable_data\add_shake'; 

% 命名匹配规则：
% 假设防抖后文件名为 "VideoA_stabilized.avi"，原始文件名为 "VideoA.avi"
suffix_to_remove = '_stabilized'; 

%% 2. 获取文件列表
files = dir(fullfile(stable_folder, '**', '*.avi')); % 根据需要修改为 *.mp4
files = files(~[files.isdir]);

if isempty(files)
    error('在 %s 中没有找到视频文件。', stable_folder);
end

% 初始化汇总数据
summary_table = table();
fprintf('开始批量评估，共 %d 个文件...\n', length(files));

%% 3. 循环处理
for i = 1:length(files)
    try
        test_name = files(i).name;
        test_path = fullfile(files(i).folder, test_name);
        
        fprintf('\n[%d/%d] 正在检查: %s\n', i, length(files), test_name);
        
        % ---------------------------------------------------------
        % [修改点] 第一步：先构造并寻找参考视频路径
        % ---------------------------------------------------------
        
        % 1.1 解析文件名，去除后缀
        [~, name_body, ext] = fileparts(test_name);
        ref_name_guess = strrep(name_body, suffix_to_remove, ''); 
        ref_name = [ref_name_guess, ext]; % 加上扩展名
        
        % 1.2 构造参考视频的完整路径
        % 计算相对路径，以支持子文件夹结构
        rel_path = erase(files(i).folder, stable_folder); 
        % 去除开头的斜杠(如果有)，防止路径拼接错误
        if startsWith(rel_path, filesep), rel_path = rel_path(2:end); end
        
        ref_path = fullfile(ref_folder, rel_path, ref_name);
        
        % ---------------------------------------------------------
        % [修改点] 第二步：判断参考视频是否存在，决定是否计算
        % ---------------------------------------------------------
        
        if isfile(ref_path)
            fprintf('  -> [匹配成功] 找到参考视频: %s\n', ref_name);
            fprintf('  -> 开始计算各项指标 (耗时操作)...\n');
            
            % --- A. 计算 ITF (自身稳定性) ---
            % 只有确认要处理这对视频时，才进行这一步计算
            itf_res = calc_video_itf(test_path);
            
            % --- B. 计算对比指标 (PSNR/SSIM) ---
            qual_res = calc_video_fidelity(ref_path, test_path);
            
            % --- C. 记录数据 ---
            new_row = table({test_name}, itf_res.itf_value, qual_res.avg_psnr, qual_res.avg_ssim, ...
                'VariableNames', {'FileName', 'ITF_Stability', 'PSNR_Fidelity', 'SSIM_Fidelity'});
            summary_table = [summary_table; new_row];
            
            fprintf('  -> [完成] ITF: %.2f, PSNR: %.2f, SSIM: %.4f\n', ...
                itf_res.itf_value, qual_res.avg_psnr, qual_res.avg_ssim);
        else
            % 如果找不到参考视频，直接跳过计算，节省时间
            fprintf(2, '  [跳过] 未找到对应的参考视频: %s\n', ref_path);
            % 如果你希望即使没有参考视频也记录一行空数据，可以取消下面这行的注释：
            % summary_table = [summary_table; table({test_name}, NaN, NaN, NaN, ...
            %    'VariableNames', {'FileName', 'ITF_Stability', 'PSNR_Fidelity', 'SSIM_Fidelity'})];
        end
        
    catch ME
        fprintf(2, '  [出错] 处理文件 %s 时发生异常: %s\n', test_name, ME.message);
    end
end

%% 4. 保存汇总结果
if ~isempty(summary_table)
    out_csv = fullfile(stable_folder, 'video_quality_report.csv');
    writetable(summary_table, out_csv);
    fprintf('\n----------------------------------\n');
    fprintf('评估完成！有效数据已保存至: %s\n', out_csv);
    disp(summary_table);
else
    fprintf('\n未能生成任何有效数据。\n');
end