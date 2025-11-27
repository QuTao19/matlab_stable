%% 单组视频质量评估脚本
clear; clc; close all;

%% 1. 选择文件
disp('步骤 1/2: 请选择 [防抖处理后] 的视频文件 (Test Video)...');
[file_test, path_test] = uigetfile({'*.avi;*.mp4;*.mov', 'Video Files'}, '选择防抖后视频');
if isequal(file_test, 0), return; end
test_full_path = fullfile(path_test, file_test);

disp('步骤 2/2: 请选择 [原始/参考] 视频文件 (Reference Video)...');
[file_ref, path_ref] = uigetfile({'*.avi;*.mp4;*.mov', 'Video Files'}, '选择参考视频', path_test);
if isequal(file_ref, 0)
    disp('未选择参考视频，仅计算 ITF。');
    ref_full_path = '';
else
    ref_full_path = fullfile(path_ref, file_ref);
end

%% 2. 计算指标
fprintf('\n正在分析...\n');

% A. 计算 ITF (自身稳定性)
res_itf = calc_video_itf(test_full_path);
fprintf('---------------------------------\n');
fprintf('文件: %s\n', file_test);
fprintf('ITF (稳定性): %.4f dB\n', res_itf.itf_value);

% B. 计算 Fidelity (如果有参考视频)
if ~isempty(ref_full_path)
    res_qual = calc_video_fidelity(ref_full_path, test_full_path);
    fprintf('PSNR (保真度): %.4f dB\n', res_qual.avg_psnr);
    fprintf('SSIM (结构相似性): %.4f\n', res_qual.avg_ssim);
    
    %% 3. 绘图可视化
    figure('Name', '视频质量分析', 'Color', 'white', 'Position', [200, 200, 800, 600]);
    
    % ITF 曲线
    subplot(3, 1, 1);
    plot(res_itf.frame_psnr, 'b');
    title(['Frame-to-Frame Stability (ITF = ' num2str(res_itf.itf_value, '%.2f') ' dB)']);
    ylabel('Inter-frame PSNR'); grid on;
    
    % PSNR 曲线
    subplot(3, 1, 2);
    plot(res_qual.psnr_list, 'r');
    title(['Fidelity PSNR (Avg = ' num2str(res_qual.avg_psnr, '%.2f') ' dB)']);
    ylabel('PSNR vs Ref'); grid on;
    
    % SSIM 曲线
    subplot(3, 1, 3);
    plot(res_qual.ssim_list, 'k');
    title(['Fidelity SSIM (Avg = ' num2str(res_qual.avg_ssim, '%.4f') ')']);
    ylabel('SSIM'); xlabel('Frame'); grid on;
end