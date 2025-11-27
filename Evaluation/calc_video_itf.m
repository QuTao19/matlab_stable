function itf_results = calc_video_itf(video_file)
% CALC_VIDEO_ITF 计算视频的 ITF 值 (基于相邻帧 PSNR)
%
% 输入:
%   video_file - 视频文件路径
% 输出:
%   itf_results - 包含结果的结构体
%       .filename    : 文件名
%       .itf_value   : 平均帧间 PSNR (dB)
%       .frame_psnr  : 每一帧相对于前一帧的 PSNR 列表
%       .num_frames  : 总帧数

    if ~isfile(video_file)
        error('找不到文件: %s', video_file);
    end

    vr = VideoReader(video_file);
    
    psnr_sum = 0;
    count = 0;
    psnr_list = [];
    prevFrame = [];
    
    % 预读取第一帧
    if hasFrame(vr)
        frame = readFrame(vr);
        if size(frame, 3) == 3
            prevFrame = rgb2gray(frame);
        else
            prevFrame = frame;
        end
    end
    
    while hasFrame(vr)
        currFrameRGB = readFrame(vr);
        
        % 转灰度
        if size(currFrameRGB, 3) == 3
            currFrame = rgb2gray(currFrameRGB);
        else
            currFrame = currFrameRGB;
        end
        
        % 计算相邻帧 PSNR
        val = psnr(currFrame, prevFrame);
        
        % 累加
        psnr_sum = psnr_sum + val;
        psnr_list = [psnr_list; val];
        count = count + 1;
        
        % 更新前一帧
        prevFrame = currFrame;
    end
    
    % 封装结果
    itf_results.filename = video_file;
    itf_results.num_frames = count + 1;
    itf_results.frame_psnr = psnr_list;
    
    if count > 0
        itf_results.itf_value = psnr_sum / count;
    else
        itf_results.itf_value = 0;
    end
end