function quality_res = calc_video_fidelity(ref_file, test_file)
% CALC_VIDEO_FIDELITY 计算相对于参考视频的 PSNR 和 SSIM
%
% 输入:
%   ref_file  - 参考视频路径 (Ground Truth 或 原始输入)
%   test_file - 测试视频路径 (防抖处理后的视频)
% 输出:
%   quality_res - 结果结构体
%       .avg_psnr  : 平均 PSNR
%       .avg_ssim  : 平均 SSIM
%       .psnr_list : 逐帧 PSNR
%       .ssim_list : 逐帧 SSIM

    if ~isfile(ref_file) || ~isfile(test_file)
        error('输入文件不存在，请检查路径。');
    end

    vRef = VideoReader(ref_file);
    vTest = VideoReader(test_file);
    
    p_list = [];
    s_list = [];
    
    % 逐帧对比循环
    while hasFrame(vRef) && hasFrame(vTest)
        fRef = readFrame(vRef);
        fTest = readFrame(vTest);
        
        % 转灰度
        if size(fRef, 3) == 3, imgRef = rgb2gray(fRef); else, imgRef = fRef; end
        if size(fTest, 3) == 3, imgTest = rgb2gray(fTest); else, imgTest = fTest; end
        
        % 尺寸对齐 (防抖算法可能会裁剪画面)
        % 策略：将 Test 缩放到 Ref 的大小
        if ~isequal(size(imgRef), size(imgTest))
            imgTest = imresize(imgTest, size(imgRef));
        end
        
        % 计算指标
        p_val = psnr(imgTest, imgRef);
        s_val = ssim(imgTest, imgRef);
        
        p_list = [p_list; p_val];
        s_list = [s_list; s_val];
    end
    
    % 封装结果
    quality_res.ref_file = ref_file;
    quality_res.test_file = test_file;
    quality_res.avg_psnr = mean(p_list);
    quality_res.avg_ssim = mean(s_list);
    quality_res.psnr_list = p_list;
    quality_res.ssim_list = s_list;
end