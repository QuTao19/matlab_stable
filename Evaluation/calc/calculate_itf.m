function [itf_score] = calculate_itf(video_path)
    % CALCULATE_ITF 计算视频的帧间转换保真度 (Inter-frame Transformation Fidelity)
    % 输入: 
    %   video_path: 视频文件路径
    % 输出:
    %   itf_score: 计算得到的 ITF 值 (dB)

    try
        v = VideoReader(video_path);
    catch ME
        warning(['无法读取视频: ', video_path]);
        itf_score = NaN;
        return;
    end

    psnr_values = [];
    
    % 读取第一帧作为前一帧
    if hasFrame(v)
        prev_frame = readFrame(v);
        if size(prev_frame, 3) == 3
            prev_frame = rgb2gray(prev_frame);
        end
        prev_frame = double(prev_frame);
    else
        itf_score = NaN;
        return;
    end

    % 逐帧计算
    while hasFrame(v)
        curr_frame = readFrame(v);
        
        % 转灰度
        if size(curr_frame, 3) == 3
            curr_frame = rgb2gray(curr_frame);
        end
        curr_frame = double(curr_frame);
        
        % 计算当前帧与前一帧的 PSNR
        % 这里的 PSNR 直接反映相邻帧的差异，差异越小（PSNR越大），视频越稳定
        score = psnr(curr_frame, prev_frame, 255);
        
        if ~isinf(score) % 排除完全相同的帧导致无穷大的情况
            psnr_values = [psnr_values; score];
        end
        
        prev_frame = curr_frame;
    end

    if isempty(psnr_values)
        itf_score = 0;
    else
        itf_score = mean(psnr_values);
    end
end