% --- 计算视频的 ITF (Inter-frame Transformation Fidelity) ---
clear; clc;

% 1. 设置视频路径
videoFile = 'unstable_data\01_input.avi'; % 替换为你的防抖后视频
videoReader = VideoReader(videoFile);

% 2. 初始化
psnr_sum = 0;
frameCount = 0;
prevFrame = [];

% 3. 循环读取并计算
while hasFrame(videoReader)
    currFrame = readFrame(videoReader);
    
    % 为了计算准确，通常转换为灰度图计算亮度分量的PSNR
    currFrameGray = rgb2gray(currFrame); 
    
    if ~isempty(prevFrame)
        % 计算相邻两帧的 PSNR
        val = psnr(currFrameGray, prevFrame);
        psnr_sum = psnr_sum + val;
        frameCount = frameCount + 1;
    end
    
    prevFrame = currFrameGray;
end

% 4. 输出结果
ITF_Value = psnr_sum / frameCount;
fprintf('视频: %s\n', videoFile);
fprintf('总帧数: %d\n', frameCount + 1);
fprintf('ITF (平均帧间 PSNR): %.4f dB\n', ITF_Value);

% 注意：ITF 值越高，代表画面越稳定（相邻帧差异越小）