% --- 计算相对于 Ground Truth 的 PSNR 和 SSIM ---
clear; clc;

% 1. 设置路径
refFile = 'unstable_data\01_input.avi';    % 原始无抖动视频
testFile = 'stable_data\01_input_stabilized.avi'; % 算法处理后的视频

vRef = VideoReader(refFile);
vTest = VideoReader(testFile);

psnr_list = [];
ssim_list = [];

% 2. 逐帧对比
while hasFrame(vRef) && hasFrame(vTest)
    frameRef = readFrame(vRef);
    frameTest = readFrame(vTest);
    
    % 转换为灰度（可选，SSIM通常在亮度通道计算）
    imgRef = rgb2gray(frameRef);
    imgTest = rgb2gray(frameTest);
    
    % 如果分辨率不一致（例如防抖裁切了），需要resize到相同大小才能计算
    if size(imgRef) ~= size(imgTest)
        imgTest = imresize(imgTest, size(imgRef));
    end
    
    % 计算指标
    p_val = psnr(imgTest, imgRef);
    s_val = ssim(imgTest, imgRef);
    
    psnr_list = [psnr_list; p_val];
    ssim_list = [ssim_list; s_val];
end

% 3. 结果分析
fprintf('平均 PSNR: %.4f dB\n', mean(psnr_list));
fprintf('平均 SSIM: %.4f\n', mean(ssim_list));

% 绘图查看每一帧的质量变化
figure;
subplot(2,1,1); plot(psnr_list); title('Frame-wise PSNR'); ylabel('dB');
subplot(2,1,2); plot(ssim_list); title('Frame-wise SSIM'); ylabel('Score');